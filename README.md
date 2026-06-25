# Introduction

This project is a 2D, real-time, physics-based fire extinguishing simulation running on the GPU.

It consists of two subsimulations: my fire/smoke simulation (https://github.com/Kamil-Kochanczyk/Fire-Smoke) and my water simulation (https://github.com/Kamil-Kochanczyk/Fluid-Smoke-Fire-Water). They work together to produce three visual effects when water particles start interacting with fire/smoke grids: water disappearing, vapor plumes forming, fire dying.

Check the above links to learn more about the subsimulations. Here we will only talk about how to extend them so that they can communicate and interact with each other to simulate fire extinguishing.

# Fire extinguishing model

## Physical basis

* Evaporating water looses its mass and disappears because it becomes a gass, i.e. water vapor.
* Water vapor itself is invisible. However, after some time has passed since the formation of this invisible gas, this invisible gas condenses into visible smoke-ish plumes which we sometimes coloquially call water vapor. This condensed gas will be simply called vapor from now on.
* Heat loss is the main reason why water can extinguish fire so well. Heating and (especially) vaporization of water steals enormous amounts energy from fire. When water appears near fire, fire looses much of its energy to heat and vaporize water. If fire energy becomes sufficiently small, then the fire cannot sustain itself and dies. Another reason why water extinguishes fire is oxygen dillution, i.e. the reduction of the amount of oxygen around fire due to vapor formation.

## Painting

Fire and smoke in the fire/smoke subsimulation can only appear on screen continuously (without immediately disappearing) if they have continuous predefined sources (in practice it means that in the original subsimulation a mouse button has to be held continuously to maintain fire and smoke on screen). **A good idea is to be able to "draw" and/or "erase" them on screen using "brushes" and/or "erasers" as if in a graphics editor.** This allows to create fire and smoke in any place on screen and easily tweak their size, strength, location etc.

**We thus extend the algorithm of the original fire/smoke subsimulation by adding the possibility to define several variables by drawing/erasing them on screen with brushes/erasers.** Those variables are listed below.

* Fire fuel injection rate $(\frac{d\rho_{\text{fuel}}}{dt})_{\text{inject}}$
  * Contributes to the fire fuel's rate of change, $\frac{d\rho_{\text{fuel}}}{dt} = (\frac{d\rho_{\text{fuel}}}{dt})_{\text{inject}} + \ldots$
* Smoke density injection rate $(\frac{d\rho_{smoke}}{dt})_{\text{inject}}$
  * Contributes to the smoke density's rate of change, $\frac{d\rho_{smoke}}{dt} = (\frac{d\rho_{smoke}}{dt})_{\text{inject}} + \ldots$
* Smoke temperature heating injection rate $(\frac{dT_{\text{smoke}}}{dt})_{\text{inject,heat}}$
  * Contributes to the smoke temperature's rate of change, $\frac{dT_{\text{smoke}}}{dt} = (\frac{dT_{\text{smoke}}}{dt})_{\text{inject,heat}} + \ldots$
* Smoke temperature cooling injection rate $(\frac{dT_{\text{smoke}}}{dt})_{\text{inject,cool}}$
  * Contributes to the smoke temperature's rate of change, $\frac{dT_{\text{smoke}}}{dt} = (\frac{dT_{\text{smoke}}}{dt})_{\text{inject,cool}} + \ldots$

Each variable gets its own brush and eraser. We assume that $(\frac{d\rho_{smoke}}{dt})_{\text{inject}}$ and $(\frac{dT_{\text{smoke}}}{dt})_{\text{inject,heat}}$ are edited with the same brush/eraser. This gives us three brushes and three erasers in total, one for each variable.

Every brush/eraser has its strength and radius which can be changed at any time. Strength determines how big values of the corresponding variable will be drawn on screen or how much of it will be erased from screen. Radius determines the region where the values will be drawn or erased. The values of the drawn variables are assumed to be non-negative.

Wherever we draw a variable with its brush, its value there becomes non-zero and, depending on the strength and radius of the brush, we can draw big, strong fires/smokes which quickly heat in some regions and small, cold fires/smokes which quickly cool in other regions. Eraser works in the opposite way, i.e. it makes the value of the variable go towards zero and can make fire/smoke more subtle both visually and in movement.

## Eulerian-Lagrangian communication
Since fire/smoke uses eulerian grids and water uses lagrangian particles, we need to find a way for both to communicate with each other, i.e. exchange information, e.g. variables.

This is done by **introducing two new grids**. To differentiate them from the eulerian grids used to simulate fire and smoke let's call them **communication grids**. Those grids  will be called ***PG Grid*** and ***GP Grid***.

The first communication grid, ***PG Grid*, is used for (lagrangian particles $\rightarrow$ eulerian grids) communication**. In other words, water particles write their properties to this grid so that fire/smoke can later read them. For example, if particles stored their current temperatures as one of their properties, *PG grid* would allow particles to contribute their temperature to *PG Grid Cells* and would allow fire/smoke to later sample *PG Grid Cells* to estimate/approximate the temperature of particles in these cells and by that estimate/approximate the temperature of particles in the corresponding fire/smoke eulerian grid cells.

The second communication grid, ***GP Grid*, is used for  (eulerian grids -> lagrangian particles) communication**. It is the opposite of *PG Grid*, i.e. water particles read some properties from this grid while fire/smoke writes some properties to this grid. For example, if fire/smoke were suppossed to increase/decrease the temperature of particles, it would first read their current temperature from *PG Grid*, apply some delta to it, and save the updated values in *GP Grid* so that particles can later read them and therefore update their temperatures.

For simplicity **we set the sizes of *PG Grid* and *GP Grid* to be the same**. This constant size **can actually be different from the size of the eulerian grids** used in the original fire/smoke subsimulation.
 
Since communication grids are grids, and since eulerian grids are grids, reading from communication grids and writing to communication grids does not pose any problems to eulerian grids (we just use simple samplers, like nearest neighbor sampling or linear sampling, depending on whether communication grids and eulerian grids are actually of the same size or not).

A bigger problem is with water particles. How are they supposed to read from or write to communication grids? There are a few ideas  but **one solution that proved to work the best (i.e. solution which is the most accurate and most resistant to numerical dissipation) is the weighted sums with bilinear interpolation weights** (bilinear because we work in 2D).

The **bilinear interpolation weights** in the normalized square where the normalized coordinates are $u$ and $v$ are:

$$w_{1} = (1 - u)(1 - v)$$
$$w_{2} = u(1 - v)$$
$$w_{3} = (1 - u)v$$
$$w_{4} = uv$$

Those weights **can actually be collapsed into one formula** dependent on the horizontal distance $d_{x}$ and vertical distance $d_{y}$ between the particle $i$ and the given grid cell $k$ (the center of grid cell $k$) (both distances should be in normalized units):

$$w_{ki} = (1 - d_{x})(1 - d_{y})$$

**When a particle wants to write its property to *PG Grid*, it distributes this property to the four neighboring grid cells (grid cell centers) using the four bilinear interpolation weights.**

However, because we have one formula independent of the type of neighbor (types are: top-left, top-right, bottom-right or bottom-left), **instead of performing bilinear interpolation *scattering* (```for each``` particle), we can perform bilinear interpolation *gathering* (```for each``` *PG Grid Cell*)**. It allows us to avoid atomic operations and race conditions between multiple particles wanting to write their contribution to the same *PG Grid Cells*.

The only thing we need to do is to **find the closest, neighboring particles for each *PG Grid Cell*, i.e. their neighborhoods, so that they can iterate over the particles within their neighborhoods to gather their contributions using the distance-dependent formula for bilinear interpolation weights**. The neighborhood of a *PG Grid Cell* $k$ is defined as all particles falling within the distance of 1 grid cell (equivalently: 1 pixel, 1 texel) from the *PG Grid Cell* $k$. This is because only those particles will have the *PG Grid Cell* $k$ as one of their four neighbors to which they will contribute their properties. This region can be viewed as a rectangle defined by the center of *PG Grid Cell* $k$ and the centers of its 8 neighboring *PG Grid Cells*. To find particles falling within this region we take advantage of the neighborhood search grid used in the water subsimulation. In the water subsimulation the neighborhood search grid is used to find the neighborhood of each particle. However, the neighborhood of a particle is defined differently (using the smoothing radius $h$) from the neighborhood of a *PG Grid Cell*. This means that we have to map the neighborhood search grid to the *PG Grid*. To be more precise, what we do is we find the intersection of neighborhood serach grid with the rectangular region around *PG Grid Cell* $k$ described earlier to find all particles within this region and to iterate over them to gather their contributions to the *PG Grid Cell* $k$.

Using the bilinear interpolation weight $w_{ki}$, in each frame, *PG Grid Cell* $k$ therefore gathers the properties from all of its neighboring particles $i$ so that fire/smoke can later read those properties and do something based on them. The properties which are gathered are listed below.

**Particle properties written to *PG Grid Cell* $k$**:

* density $\rho_{\text{pg},k}$

$$
\rho_{\text{pg},k} = \sum_{i \in N(k)} w_{ki}
$$

* energy $E_{\text{pg},k}$

$$
E_{\text{pg},k} = \frac{1}{\rho_{\text{pg},k}}\sum_{i \in N(k)} w_{ki}E_{i}
$$

* evaporated mass $m_{\text{pg},k}^{\text{evap}}$

$$
m_{\text{pg},k}^{\text{evap}} = \frac{1}{\rho_{\text{pg},k}}\sum_{i \in N(k)} w_{ki}m_{i}^{\text{evap}}
$$

This is all regarding *PG Grid*. Now *GP Grid*.

Since we assumed the same sizes of *PG Grid* and *GP Grid*, when we need the values from *PG Grid* to be transferred to *GP Grid* we simply have $\rho_{\text{gp},k} = \rho_{\text{pg},k}$, $E_{\text{gp},k} = E_{\text{pg},k}$, $m_{\text{gp},k}^{\text{evap}} = m_{\text{pg},k}^{\text{evap}}$, i.e. the values from *PG Grid* can be directly passed to *GP Grid* without any interpolation.

*GP Grid* is used this time not to write particle properties but to read them. **When a particle wants to read some property from *GP Grid*, it performs the weighted sum with bilinear interpolation weights just like before.** This time however it is simpler as it just requires finding the nearest four neighboring *GP Grid Cells* for each particle and use the weights $w_{1}, w_{2}, w_{3}, w_{4}$ to calculate the desired particle property, without having to worry about race conditions (because read-only operation does not require synchronisation or tricks like *gather* instead of *scatter*).

In each frame, the properties that are written by fire/smoke to *GP Grid Cell* $k$ and read later by particles are listed below.

**Particle properties read from *GP Grid Cell* $k$**:
 
* delta particle energy $\Delta E_{\text{gp},k}$

$$
\Delta E_{i} = \frac{w_{1}\Delta E_{\text{gp,k1}} + w_{2}\Delta E_{\text{gp,k2}} + w_{3}\Delta E_{\text{gp,k3}} + w_{4}\Delta E_{\text{gp,k4}}}{w_{1} + w_{2} + w_{3} + w_{4}}
$$

* new (modified, updated) particle energy $E_{\text{gp},k}^{\text{new}}$

$$
E_{i}^{\text{new}} = \frac{w_{1}E_{\text{gp,k1}}^{\text{new}} + w_{2}E_{\text{gp,k2}}^{\text{new}} + w_{3}E_{\text{gp,k3}}^{\text{new}} + w_{4}E_{\text{gp,k4}}^{\text{new}}}{w_{1} + w_{2} + w_{3} + w_{4}}
$$

* heat transfer amount from fire to water $\Delta H_{\text{gp},k}$

$$
\Delta H_{i} = \frac{w_{1}\Delta H_{\text{gp,k1}} + w_{2}\Delta H_{\text{gp,k2}} + w_{3}\Delta H_{\text{gp,k3}} + w_{4}\Delta H_{\text{gp,k4}}}{w_{1} + w_{2} + w_{3} + w_{4}}
$$

* particle density $\rho_{\text{gp},k}$

$$
\rho_{\text{gp},k} = \rho_{\text{pg},k}
$$

Here subscripts $_{\text{k1}}$, $_{\text{k2}}$, $_{\text{k3}}$, $_{\text{k4}}$ denote four surrounding *GP Grid Cells* (neighbors) of particle $i$.

Particle density in case of *GP Grid* is actually not used to calculate any particle property, its role is different. **Particle density is used to discard from weighted sums those *GP Grid Cells* which contain no particles at all, i.e. those *GP Grid Cells* where $\rho_{\text{gp},k} = \rho_{\text{pg},k} = 0$**. We discard such grid cells from the weighted sum as **we assume that wherever there are no particles, their properties are undefined there**. Moreover, **not discarding such grid cells would cause problems with numerical dissipation** (reading zeros from cells increases numerical dissipation).

Here, 25.06.2026

## Water evaporation

Water disappearing upon getting in contact in fire is one of the visual effects that this simulation is suppossed to simulate.

To achieve this we introduce a new quantity stored by a particle $i$. This quantity is the current energy $E_{i}$ stored by the particle, $0 \le E_{i} \le E_{\text{max}}$. The total energy that the particle can store is the sum of: (1) the heating energy required to heat the particle from its default temperature to its boiling temperature and (2) the vaporization energy required to completely evaporate the particle, i.e. $E_{\text{max}} = E_{\text{heating}} + E_{\text{vaporization}}$. The heating energy is defined as $E_{\text{heating}} = m_{i} \cdot c_{w} \cdot \left(T_{\text{boiling}} - T_{\text{ambient}} \right)$, where $m_{i}$ is the mass of the particle, $c_{w} = 4184 \frac{J}{kg \cdot K}$ is the specific heat capacity of water, $T_{\text{boiling}} = 373 K$ is the boiling temperature of water and $T_{\text{ambient}}$ is the initial temperature of the particle. The vaporization energy is defined as $E_{\text{vaporization}} = m_{i} \cdot L_{w}$ where $L_{w} = 2264705 \frac{J}{kg}$ is the specific latent heat of vaporization of water.

The energy $E_{i}$ is first initialized to $0$. It is then increased by the energy (heat) transfer mechanism when a particle starts interacting with fire and "stealing" fire's energy (heat) to increase its own energy. If $0 \leq E_{i} \leq E_{\text{heating}}$, then we interpret it as the particle being in the heating stage when its temperature is being increased. If $E_{\text{heating}} \lt E_{i} \leq E_{\text{max}}$, then we interpret it as the particle being the vaporization stage when its mass is being lost. When $E_{i}$ reaches its maximum possible value, then the particle is killed as we assume that is when the total evaporation occurs and the entire mass is lost.

The fact that vaporization is the main reason why water is such a good extinguishing agent is encoded in the fact that in the simulation $E_{\text{heating}} \lt\lt E_{\text{vaporization}}$.

In practice the energy of the particles is increased on the GP grid by the fire/smoke subsimulation.

First of all, the temperature and the latent heat of particles in the GP grid cell $i$ are calculated based on the current energy of particles:

$$
T_{\text{water,gp},i} = T_{ambient} + \frac{\min(E_{\text{gp},i}, E_{\text{heating}})}{m_{j}c_{w}}
$$

$$
H_{\text{latent,gp},i} = \max(E_{\text{gp},i} - E_{\text{heating}}, 0)
$$

Then the heat transfer amount from fire to water, $\Delta H_{\text{gp},i} \geq 0$, is calculated. We assume that heat transfer occurs only if fire temperature in the GP grid cell $i$ is greater than the maximum temperature that a particle can have, i.e. $\Delta H_{\text{gp},i} \gt 0 \iff T_{\text{fire,gp},i} \gt T_{\text{boiling}}$, otherwise $\Delta H_{\text{gp},i} = 0$. In other words, in the simulation we do not worry about the case when the heat is transferred from water to fire. One additional check that we can do is to check if $\rho_{\text{gp},i} = \rho_{\text{pg},i} = 0$ and also assume that in that case $\Delta H_{\text{gp},i} = 0$.

When the heat transfer occurs, we assume a simplified, conduction-like heat transfer from fire to water:

$$
\frac{d(\Delta H_{\text{gp},i})}{dt} = kA(T_{\text{fire,gp},i} - T_{\text{water,gp},i})
$$

Here $A$ is the area of GP grid cell and $k$ is a tunable parameter used to control the speed of heat transfer.

If we have the heat transfer budget $\Delta H_{\text{gp},i}$ for the current frame, we use differently depending on two cases:

* if $T_{\text{water,gp},i} \lt T_{\text{boiling}}$, then the entire heat transfer budget is used to increase the particles temperature, $T_{\text{water,gp},i} += \frac{H_{\text{used}}}{m_{j}c_{w}}$
* if $T_{\text{water,gp},i} = T_{\text{boiling}}$, then the entire heat transfer budget is spent to increase the particles latent heat, $H_{\text{latent,gp},i} += \min(\Delta H_{\text{gp},i} - H_{\text{used}}, E_{\text{vaporization}} - H_{\text{latent,gp},i})$
* $H_{\text{used}} = \min(\Delta H_{\text{gp},i}, E_{\text{heating}} - \min(E_{\text{gp},i}, E_{\text{heating}}))$
* a special case is when the particles temperature is almost at its boiling point and the current heat transfer budget is bigger than we need; then, after increasing the particles temperature some of the heat transfer budget remains unused; this entire leftover is then used to increase the latent heat of particles

We can see that $k$ controls both the speed of heating and the speed of vaporization. However, it may be good to be able to control heating and vaporization of water separately, using two different paramters, one for heating and one for vaporization. So in our simulation we use:

* $\frac{d(\Delta H_{\text{gp},i})}{dt} = A(T_{\text{fire,gp},i} - T_{\text{water,gp},i})$
* $T_{\text{water,gp},i} += k_{\text{heating}} \frac{H_{\text{used}}}{m_{j}c_{w}}$
* $H_{\text{latent,gp},i} += k_{\text{vaporization}} \min(\Delta H_{\text{gp},i} - H_{\text{used}}, E_{\text{vaporization}} - H_{\text{latent,gp},i})$
* $H_{\text{used}} = \min(\Delta H_{\text{gp},i}, E_{\text{heating}} - \min(E_{\text{gp},i}, E_{\text{heating}}))$, $k_{\text{heating}}$ and $k_{\text{vaporization}}$ are tunable paramters controlling the speed of heating and vaporization respectively

We recalculate $\Delta H_{\text{gp},i}$ each frame (we do not accumulate it so we assume if some of it reamains at the end of the frame we assume that it is lost to the environment and forget about it).

Based on the updated temperature and latent heat we compute the new energy:

$$
E_{\text{gp,new},i} = [m_{j} c_{w} (T_{\text{water,gp},i} - T_{\text{ambient}})] + H_{\text{latent,gp},i};
$$

Delta particle energy is calculated:

$$
\Delta E_{\text{gp},i} = E_{\text{gp,new},i} - E_{\text{gp},i}
$$

Finally, $E_{\text{gp,new},i}$, $\Delta E_{\text{gp},i}$, $\Delta H_{\text{gp},i}$ and $\rho_{\text{gp},i}$ are stored in the GP grid cell. Later, particles near this grid cell read the values $E_{\text{gp,new},i}$, $\Delta E_{\text{gp},i}$, and $\Delta H_{\text{gp},i}$ stored their and use them in the weighted sum formulas presented earlier to calculate $\Delta E_{j}$, $E_{\text{new},j}$ and $\Delta H_{j}$. As we remember, $\rho_{\text{gp},i}$ is used to discard undefined grid cells.

Now, the particles should increase their energy budget. Inspired by PIC-FLIP blending we calculate new energy of a particle $j$ using linear interpolation:

$$
E_{\text{new},j} = (1 - t)(E_{\text{old},j} + \Delta E_{j}) + tE_{\text{new},j}
$$

Here $t \in [0,1]$ is a tunable interpolation factor. When its values are near zero, we get grainy, noisy energy updates, i.e. particles which are near one another can have very different temperatures and latent heats and die at very different times. When its values are near one, we get more smooth energy updates, i.e. most particles which are near will have similar, pretty much the same energy and die at approximately the same time. The idea behind this blending is to make it as grainy as possible because smoothing causes the loss of details, but make it smooth enough so that as many particles as possible die at approximately the same time. We want the particles to die at the same time (due to evaporation) because it seems that dying particles are the source of instabilities. If we make particles disappear one by one it can cause particles to start moving very rapidly and eventually blow up sometimes. If we make them disappear in groups it seems that they behave more stable.

One final note is that we perform particle energy update only when $\Delta H_{j} \gt 0$. This is done because particle updates based on values read from GP grid are not very accurate and in practice many particles can have energies which do not always monotonically increase, i.e. sometimes the energy of the particle can be lower than previously which is in contradiction with out assumption that heat transfer occurs only from fire to water. In general, GP grid updates proved to both artificially loose and create energy. This is why want to limit ourselves only to the regions near the fire, where we know that the water will interact with fire. Those regions are suppossed to be marked by the non-zero values of $\Delta H_{j} \gt 0$ and are suppossed to be the regions where the fire is strong and visibly burning on screen. This condition, i.e. $\Delta H_{j} \gt 0$, is also important in the case of formation of vapor as it will be explained in the next section.

And finally, we have not yet talked about $m_{\text{evap}}$ as this variable will be crucial in the next section for the modelling of vapor. We calculate it based on the change in the latent heat due to energy change:

$$
m_{\text{evap},j} = m_{j}\frac{H_{\text{latent,new}} - H_{\text{latent,old}}}{E_{\text{vaporization}}}
$$

$$
H_{\text{latent,new}} = H_{\text{latent,new}}(E_{\text{new},j})
$$

$$
H_{\text{latent,old}} = H_{\text{latent,old}}(E_{\text{old},j})
$$

The assumption is that we associate full mass $m_{j}$ with particles having energy $E_{j} \leq E_{\text{heating}}$ but for particles with $E_{j} \gt E_{\text{heating}}$ we have a linear decrease in mass, i.e. for $E_{j} = E_{\text{heating}}$ mass is still $m_{j}$ but for $E_{j} = E_{\text{max}}$ mass is $0$ and for values in between it changes linearly.

Note that $m_{j}$ is simply a scaling constant so to avoid small numbers in calculations we can assume the relationship given below and use another, manually tuned scaling constant later if needed:

$$
m_{\text{evap},j} = \frac{H_{\text{latent,new}} - H_{\text{latent,old}}}{E_{\text{vaporization}}}
$$

Also, it turns out that it is better to always use the same, unchanged constant mass $m_{j}$ for SPH particle calculations instead of physically correct mass which decreases as particle increases its latent heat. This is because experiments showed that using variable mass of particles, i.e. mass that goes decreases to zero, makes the particles unstable and they often blow up when mass is gets smaller and smaller.
## Vapor plumes formation

Another visual effect that we want to model is the formation of smoke-ish plumes which are suppossed to represent condensed water vapor and should appear when the water is evaporating, i.e. losing mass.

To do this we take advantage of the existing fire/smoke subsimulation. It can already simulate the natural smoke which forms during fires. We have much freedom in choosing  where this smoke appears, how big and aggressive it is and what color it has. As for condensed water vapor, we can also view it as a kind of smoke. The difference is that we assume that condensed water vapor is a highly specific type of smoke. We assume that it has a very light, white-ish color, is injected only when water is evaporating/loosing mass and its intensity depends on how much water there is. But we do not create another, separate smoke subsimulation just to simulate this specific kind of smoke as this would be inefficient.

Instead, we introduce a new variable to the smoke algorithm. Let's call this variable $\rho_{\text{vapor}}$, $0 \leq \rho_{\text{vapor}} \leq 1$. We can interpret it as the density of the vapor or as a fuzzy boolean variable which tells us how 'vapor-ish' the smoke is or as the strength of the 'vaporness' of the smoke at any given region. Its main role is to help visually mark the vapor using a different color and blend it with the normal smoke's color.

This variable is updated according to:

$$
\frac{d\rho_{\text{vapor}}}{dt} = -(\mathbf{u} \cdot \nabla)\rho_{\text{vapor}} + m_{\text{evap,pg}}\rho_{\text{pg}}k_{\text{vapor,density,inject}} - k_{\text{vapor,density,dissipate}}
$$

The blending between vapor color and smoke color is done according to:

$$
C_{\text{final}} = (1 - \rho_{\text{vapor}})C_{\text{smoke}} + \rho_{\text{vapor}}C_{\text{vapor}}
$$

Each timestep the injection term also contributes to the smoke density $\rho_{\text{smoke}}$ so that the vapor can appear on screen:

$$
\rho_{smoke} += m_{\text{evap,pg}}\rho_{\text{pg}}k_{\text{vapor,density,inject}}dt
$$

Each timestep the injection term also contributes to the smoke temeperature $T_{smoke}$ so that the vapor can either quickly rise up or slowly fall down:

$$
T_{smoke} += m_{\text{evap,pg}}\rho_{\text{pg}}k_{\text{vapor,temperature,inject}}dt
$$

Here $m_{\text{evap,pg}}$ and $\rho_{\text{pg}}$ are the values read by the smoke from the PG grid, while $k_{\text{vapor,density,inject}}$ and $k_{\text{vapor,density,dissipate}}$ are tunable parameters controlling the strength of injection and dissipation of $\rho_{\text{vapor}}$, respectively while $k_{\text{vapor,temperature,inject}}$ is also a tunable parameter which controls the strength of vapor's temperature injection.

The equations above are suppossed to encode the following behaviors of vapor:

* $\rho_{\text{vapor}}$ is advected along the smoke's velocity field so that we can keep track of which smoke regions are vapor as oppossed to natural smoke by coloring it differently; its injection and dissipation help blend between the two naturally
* the injection term:
  * causes the vapor to appear (density injection) and to start moving due to buoyancy (temperature injection)
  * works only when there is some water evaporating, i.e. only when $m_{\text{evap,pg}} \gt 0$
  * injects more density and temperature if there is more water being evaporated, i.e. more evaporating water = more vapor, the term responsible for this is the product $m_{\text{evap,pg}}\rho_{\text{pg}}$, it was found experimentally and turned out to give this desired result

Based on the above we can now explain why the condition $\Delta H_{j} \gt 0$ is important for the formation of vapor. Let's remind ourselves that this condition is used to ensure that particle energies are updated only near the regions of strong/visible fire. Far from fire particle energies are not updated. Because evaporated mass is calculated based on change in latent heats, and change in latent heats is directly related to change in energy, this means that far from fire evaporated masses will always be zero, i.e. the mass will only evaporate near the fire, where the heat transfer occurs. This is a crucial assumption because, as we explained earlier, inaccuracies that arise when using PG and GP grids can cause wrong updates of energies, i.e. they do not always monotonically increase their energies, sometimes they may oscillate a bit while increasing. This can cause wrong changes in energy and therefore wrong changes in latent heats and because of this wrong values of evaporated masses and wrong visual effects of vapor appearing when it should not and in quantities that are not correct. By ensuring that energies change only near the regions of fire, we make the assumption that water only evaporates near fire which is a simplification but provides more control over the visual effects.

There is one important limitation of the above approach, however. If we used a separate smoke subsimulation, i.e. with separate variables, like velocity, just for the vapor we would have full control over it. By using the same existing subsimulation for simulation of both the smoke and the vapor we loose a little bit of control over the vapor. This is because both smoke and vapor use the same velocity field and, for example, when we have a predefined smoke source which makes it move quickly upwards and when we have a vapor that is tuned to move slowing downwards when injected, we get the desired vapor behavior only in the regions where there is no smoke. In the regions where there is also smoke, i.e. where the two blend, the velocity of the smoke will be visually inherited by the vapor as the variable $\rho_{\text{vapor}}$ will be advected along a very quick velocity near the smoke region which will give the visual result of vapor moving quickly with the smoke even though we specified it to be slow.

## Flame extinguishing

Final visual effect that we want to model is fire extinguishment upon interacting with water. There are many approaches that we can take but the one that turned out to work the best in practice is the approach described below.

The first thing we do is change the combustion model a little bit. This is because the original model overwrites fire's temperature in each by using the max function:

$$
T_{\text{fire}} = \text{max}(T_{\text{fire}}, \rho_{\text{fuel}} * T_{\text{burn}})
$$

Instead, we would like to have a model where each variable is updated using the timestep as this helps in modelling continuous changes like gradual extinguishment or reignition. This is why we modify the above equation and use it to contribute to the rate of change fire temperature:

$$
\left(\frac{dT_{\text{fire}}}{dt}\right)_{\text{inject}} = \rho_{\text{fuel}} \cdot T_{burn} \cdot k_{\text{release}}
$$

Here $k_{\text{release}}$ is a tunable parameter defining how fast the heat is introduced into the system by the fuel.

With this change in place, we can now model the responsiveness of fire temperature to the heat stolen by water:

$$
\left(\frac{dT_{\text{fire}}}{dt}\right)_{\text{extinguish}} = -\left( k_{\text{sensitivity}} \cdot \Delta H_{\text{gp},i} \right)
$$

Here $k_{\text{sensitivity}}$ is another tunable parameter which defines how much fire is cooled when it contacts water.

The above is just used to provide a visual feedback, it is not the direct mechanism of extinguishment. The proper exitnguishment is done not by attacking the temperature of the fire itself but by attacking the fuel injection mask. Fuel injection mask provides fuel -> fuel provides temperature -> temperature gives visual fire. Som, removing fuel injection mask = removing visual fire. This is why we wish to attack the very base of this chain.

We introduce a new variable, an extinguish mask $m_{\text{extinguish}}$, $0 \leq m_{\text{extinguish}} \leq 1$. When $m_{\text{extinguish}} = 0$ it means that fire in this region is not extinguished. When $m_{\text{extinguish}} = 1$ it means that fire in this region is completely extiguished. Values in between blend linearly between the two edge cases.

With extinguish mask we alter the equation for fuel injection:

$$
(\frac{d\rho_{\text{fuel}}}{dt})_{\text{inject}} = k_{\text{fuel,inject}} \cdot (1 - m_{\text{extinguish}})
$$

Here $k_{\text{fuel,inject}}$ is the constant fuel inject rate painted by the fuel brush.

Extinguish mask itself is initialized to zero at the very beginning. It is increased or decreased but only in the regions where the painted fuel mask is non-zero, i.e. in places where there is a continuous fuel injection rate specified. When water interacts with fire, it is increased with some rate dependent on the water properties and this way we can model gradual extinguishing. To model gradual reignition we also make the extinguish mak decrease its values on its own. In other words, fire makes the extinguish mask go to zero while water makes the extinguish mask go to one. We assume that if water is strong enough to "beat" fire and make the extiguish mask reach the value one, then the fire in the given region is extinguished and stays extinguished until we e.g. reset the simulation with a key press or something similar. That is, when the extinguish mask reaches the value of one, it is no longer increased nor decreased, it stays at this value, and the fire in this region is extinguished, until manual reset.

The rate at which water extinguishes fire is modelled using three phenomena.

The first one is cooling which is modelled as the difference between fire temperature before and after $\left(\frac{dT_{\text{fire}}}{dt}\right)_{\text{extinguish}}$ has been applied to reduce fire temperature. The bigger, the stronger the extinguishing.

$$
\left( \frac{dm_{\text{extinguish}}}{dt} \right)_{\text{cooling}} = k_{\text{cooling}} \cdot (T_{\text{fire,before}} - T_{\text{fire,after}})
$$

The second one (the most important one) is evaporation. We reuse the same term $m_{\text{evap,pg}}\rho_{\text{pg}}$ as in the case of vapor formation. The bigger, the stronger the extinguishing.

$$
\left( \frac{dm_{\text{extinguish}}}{dt} \right)_{\text{evaporation}} = k_{\text{evaporation}} \cdot m_{\text{evap,pg}}\rho_{\text{pg}}
$$

The third one, I am not sure how to call it. It is an auxiliary term. We use it because the previous two terms are directly dependent on the heat transfer from fire to water which itself is directly dependent on the temperature difference between fire and water. This means that the more the fire gets extinguished and lowers its temperature, the difference in temperatures in fire and water gets smaller and smaller which makes heat transfer smaller and smaller which finally makes the two extinguishing termns above smaller and smaller. In the end it just means that with the above two terms it is hard to extinguish weak fires and achieve 100\% extinguish mask overlayed on the fuel mask. To counteract this we introduce an auxiliary extinguishing term which is non-zero only if there is some water present and becomes relevant, i.e. with values significantly greater than zero, when the previous two terms approach zero. The formula for this behaviour that proved to work well is:

$$
\left( \frac{dm_{\text{extinguish}}}{dt} \right)_{\text{aux}} = \frac{k_{\text{aux}}\rho_{\text{pg}}}{[k_{\text{cooling}} \cdot (T_{\text{fire,before}} - T_{\text{fire,after}})] + [k_{\text{evaporation}} \cdot m_{\text{evap,pg}}\rho_{\text{pg}}] + 1.0}
$$

The number one in the denominator is used to prevent divisions by zero.

The rate at which fire reignites on its own is given by.

$$
\left( \frac{dm_{\text{extinguish}}}{dt} \right)_{\text{reignite}} = -k_{\text{reignite}}
$$

Parameters $k_{\text{cooling}}$, $k_{\text{evaporation}}$, $k_{\text{aux}}$, $k_{\text{reignite}}$ are tunable parameters.

The total rate of change of extinguish mask is then:

$$
\frac{dm_{\text{extinguish}}}{dt} = \left( \frac{dm_{\text{extinguish}}}{dt} \right)_{\text{cooling}} + \left( \frac{dm_{\text{extinguish}}}{dt} \right)_{\text{evaporation}} + \left( \frac{dm_{\text{extinguish}}}{dt} \right)_{\text{aux}} + \left( \frac{dm_{\text{extinguish}}}{dt} \right)_{\text{reignite}}
$$
