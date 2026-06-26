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
* Smoke density injection rate $(\frac{d\rho_{\text{smoke}}}{dt})_{\text{inject}}$
  * Contributes to the smoke density's rate of change, $\frac{d\rho_{\text{smoke}}}{dt} = (\frac{d\rho_{\text{smoke}}}{dt})_{\text{inject}} + \ldots$
* Smoke temperature heating injection rate $(\frac{dT_{\text{smoke}}}{dt})_{\text{inject,heat}}$
  * Contributes to the smoke temperature's rate of change, $\frac{dT_{\text{smoke}}}{dt} = (\frac{dT_{\text{smoke}}}{dt})_{\text{inject,heat}} + \ldots$
* Smoke temperature cooling injection rate $(\frac{dT_{\text{smoke}}}{dt})_{\text{inject,cool}}$
  * Contributes to the smoke temperature's rate of change, $\frac{dT_{\text{smoke}}}{dt} = (\frac{dT_{\text{smoke}}}{dt})_{\text{inject,cool}} + \ldots$

Each variable gets its own brush and eraser. We assume that $(\frac{d\rho_{\text{smoke}}}{dt})_{\text{inject}}$ and $(\frac{dT_{\text{smoke}}}{dt})_{\text{inject,heat}}$ are edited with the same brush/eraser. This gives us three brushes and three erasers in total, one for each variable.

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
\rho_{\text{gp},k1} = \rho_{\text{pg},k1}, \rho_{\text{gp},k2} = \rho_{\text{pg},k2}, \rho_{\text{gp},k3} = \rho_{\text{pg},k3}, \rho_{\text{gp},k4} = \rho_{\text{pg},k4}
$$

Here subscripts $_{\text{k1}}$, $_{\text{k2}}$, $_{\text{k3}}$, $_{\text{k4}}$ denote four surrounding *GP Grid Cells* (neighbors) of particle $i$.

Particle density in case of *GP Grid* is actually not used to calculate any particle property, its role is different. **Particle density is used to discard from weighted sums those *GP Grid Cells* which contain no particles at all, i.e. those *GP Grid Cells* where $\rho_{\text{gp},k} = \rho_{\text{pg},k} = 0$**. We discard such grid cells from the weighted sum as **we assume that wherever there are no particles, their properties are undefined there**. Moreover, **not discarding such grid cells would cause problems with numerical dissipation** (reading zeros from cells increases numerical dissipation).

## Water vaporization

One of the visual effects that this simulation is suppossed to simulate is the disappearance of water upon contact with fire.

To achieve this **we introduce a new quantity stored by each particle $i$ and this quantity is the current energy $E_{i}$** stored by the particle $i$, $0 \le E_{i} \le E_{\text{max}}$.

The total energy that the particle can store is **the sum of: (1) the heating energy required to heat the particle from its default temperature to its boiling temperature and (2) the vaporization energy required to completely evaporate the particle**

$$E_{\text{max}} = E_{\text{heating}} + E_{\text{vaporization}}
$$

**The heating energy is defined using a simple relationship from thermodynamics:**

$$E_{\text{heating}} = m c_{\text{water}} (T_{\text{water,boiling}} - T_{\text{water,ambient}})
$$

Here $m$ is the (constant) mass of each particle, $c_{\text{water}} = 4184 \frac{J}{kg \cdot K}$ is the specific heat capacity of water, $T_{\text{water,boiling}} = 373 K$ is the boiling temperature of water and $T_{\text{water,ambient}}$ is the initial temperature of each particle.

**The vaporization energy is defined as another simple relationship from thermodynamics:**

$$E_{\text{vaporization}} = m L_{\text{water}}
$$

Here $L_{\text{water}} = 2264705 \frac{J}{kg}$ is the specific latent heat of vaporization of water.

The energy $E_{i}$ of particle $i$ is **first initialized to $0$**. It is **then increased by the energy (heat) transfer from fire to water**. Currently, for simplicity, **energy loss is not modeled**, i.e. $E_{i}$ can only increase and cannot decrease. When particle $i$ starts interacting with fire **it steals fire's energy (heat) to increase its own energy**. If $0 \leq E_{i} \leq E_{\text{heating}}$, then **we interpret it as the particle being in the heating stage, i.e. the stage when its temperature is being increased**. If $E_{\text{heating}} \lt E_{i} \leq E_{\text{max}}$, then **we interpret it as the particle being in the vaporization stage, i.e. the stage when its mass is being lost**. When $E_{i}$ reaches its **maximum possible value, then the particle is killed** as we assume that this is when the total vaporization occurs and the entire mass is lost.

The fact that vaporization is the main reason why water is such a good extinguishing agent is encoded in the fact that in the simulation $E_{\text{heating}} \lt\lt E_{\text{vaporization}}$.

The energy $E_{i}$ is first transferred from particle $i$ to *PG Grid*, later it is moved to *GP Grid* and updated there by the fire/smoke subsimulation and finally it is transferred back from *GP Grid* to particle $i$.

The **update scheme performed on the *GP Grid*** is described below.

First of all, **the temperature and the latent heat of particles in the *GP Grid Cell* $k$ are calculated**:

$$
T_{\text{water,gp},k} = T_{\text{water,ambient}} + \frac{\min(E_{\text{gp},k}, E_{\text{heating}})}{m c_{\text{water}}}
$$

$$
H_{\text{latent,gp},k} = \max(E_{\text{gp},k} - E_{\text{heating}}, 0)
$$

**Then, heat transfer from fire to water, $\Delta H_{\text{gp},k} \geq 0$, is calculated. We assume that heat transfer occurs only if fire temperature in the *GP Grid Cell* $k$ is greater than the maximum particle temperature:**

$$
\Delta H_{\text{gp},k} \gt 0 \iff T_{\text{fire,gp},k} \gt T_{\text{water,boiling}}
$$

$$
\Delta H_{\text{gp},k} = 0 \iff T_{\text{fire,gp},k} \leq T_{\text{water,boiling}}
$$

In other words, in the simulation we do not worry about the case when heat is transferred from water to fire and **we assume only one-way heat transfer, i.e. from fire to water**. Because fire visualization is directly based on the temperature of fire, heat transfer form water to fire could theoretically make the fire visible on screen just due to water losing its energy and we do not want that.

One more thing that we do is to **check if $\rho_{\text{gp},k} = \rho_{\text{pg},k} = 0$** as we do not process undefined cells.

When heat transfer can occur and should be non-zero **we assume a simplified, conduction-like heat transfer from fire to water**:

$$
\frac{d(\Delta H_{\text{gp},k})}{dt} = k_{\text{heat,transfer}}A_{k}(T_{\text{fire,gp},k} - T_{\text{water,gp},k})
$$

Here $k_{\text{heat,transfer}}$ is a tunable parameter used to control the speed of heat transfer and $A_{k}$ is the area of *GP Grid Cell* $k$ through which we assume that heat transfer occurs.

**Heat transfer in the current frame** (also called heat transfer budget from now on) is:

$$
\Delta H_{\text{gp},k} \approx k_{\text{heat,transfer}}A_{k}(T_{\text{fire,gp},k} - T_{\text{water,gp},k})dt
$$

**It is recalculated each frame, we do not store it**, i.e. we assume that if there is some heat transfer unused by water in the current frame, then we forget about it and e.g. assume that it is lost to the environment.

If we have $\Delta H_{\text{gp},k}$ for the current frame, **we use it differently depending on two cases**:

* (1) if $T_{\text{water,gp},k} \lt T_{\text{water,boiling}}$, then it is used to increase the temperature of particles

$$
T_{\text{water,gp},k}^{\text{new}} =  T_{\text{water,gp},k} + \frac{\Delta H_{\text{used}}}{m c_{\text{water}}}
$$

* (2) if $T_{\text{water,gp},k} = T_{\text{water,boiling}}$, then it is used to increase the latent heat of particles

$$
H_{\text{latent,gp},k}^{\text{new}} =  H_{\text{latent,gp},k} + \min(\Delta H_{\text{gp},k} - \Delta H_{\text{used}}, E_{\text{vaporization}} - H_{\text{latent,gp},k})
$$

The value of $\Delta H_{\text{used}}$ represents how much heat from heat transfer budget for the current frame has been used to increase the temperature of water. It is calculated using the current energy of particles and the desirable energy of particles that they need to reach the boiling point:

$$
\Delta H_{\text{used}} = \min(\Delta H_{\text{gp},k}, E_{\text{heating}} - \min(E_{\text{gp},k}, E_{\text{heating}}))
$$

A special case (already covered by the above equations) is when the temperature of particles is almost at its boiling limit and the current heat transfer budget is bigger than we need to reach this boiling limit. Then, after increasing the temperature of particles, some of the heat transfer budget remains unused. This entire leftover is in that case used to increase the latent heat of particles.

We can see that $k_{\text{heat,transfer}}$ controls both the speed of heating and the speed of vaporization. However, **it may be good to be able to control heating and vaporization of water separately, using two different parameters, one for heating and one for vaporization**. Indeed, instead of the above equations in the simulation we use:

$$
\frac{d(\Delta H_{\text{gp},k})}{dt} = A_{k}(T_{\text{fire,gp},k} - T_{\text{water,gp},k})
$$

$$
\Delta H_{\text{gp},k} \approx A_{k}(T_{\text{fire,gp},k} - T_{\text{water,gp},k})dt
$$

$$
T_{\text{water,gp},k}^{\text{new}} = T_{\text{water,gp},k} + k_{\text{heating}} \frac{\Delta H_{\text{used}}}{m c_{\text{water}}}
$$

$$
H_{\text{latent,gp},k}^{\text{new}} = H_{\text{latent,gp},k} + k_{\text{vaporization}} \min(\Delta H_{\text{gp},k} - \Delta H_{\text{used}}, E_{\text{vaporization}} - H_{\text{latent,gp},k})
$$

$$
\Delta H_{\text{used}} = \min(\Delta H_{\text{gp},k}, E_{\text{heating}} - \min(E_{\text{gp},k}, E_{\text{heating}}))
$$

Here $k_{\text{heating}}$ and $k_{\text{vaporization}}$ are tunable parameters controlling the speed of heating and the speed of vaporization respectively.

**Based on updated temperature and updated latent heat we compute updated energy:**

$$
E_{\text{gp},k}^{\text{new}} = [m c_{\text{water}} (T_{\text{water,gp},k}^{\text{new}} - T_{\text{water,ambient}})] + H_{\text{latent,gp},k}^{\text{new}}
$$

**Delta particle energy is also calculated based on how much the updated energy increased compared to the original one (before the updates):**

$$
\Delta E_{\text{gp},k} = E_{\text{gp},k}^{\text{new}} - E_{\text{gp},k}
$$

**Finally, $\Delta E_{\text{gp},k}$, $E_{\text{gp},k}^{\text{new}}$, $\Delta H_{\text{gp},k}$ and $\rho_{\text{gp},k}$ are stored in the *GP Grid Cell* $k$**. Later, particle ${i}$ near this cell reads the values of $\Delta E_{\text{gp},k}$, $E_{\text{gp},k}^{\text{new}}$, $\Delta H_{\text{gp},k}$ stored there and uses them in the weighted sum formulas presented earlier to calculate $\Delta E_{i}$, $E_{i}^{\text{new}}$ and $\Delta H_{i}$. As we remember, $\rho_{\text{gp},k}$ is used to discard undefined grid cells.

The work on the grid has been finished and now it is time for the particles to increase their energies somehow. **Inspired by PIC-FLIP blending we calculate the new energy of particle $i$ using linear interpolation between PIC-style update and FLIP-style update**:

$$
E_{i}^{n} = (1 - t)(E_{i}^{n - 1} + \Delta E_{i}) + tE_{i}^\text{new}
$$

Here superscripts $^{n}$ and $^{n - 1}$ are used to differentiate between the energy of particle $i$ in the current frame and in the previous frame, respectively.

As for $t$, $t \in [0,1]$, it is a tunable parameter, an interpolation factor. **When its values are near zero, we get grainy, noisy, FLIP-like energy updates**, i.e. particles which are near one another can have very different temperatures and latent heats and die at very different times when subjected to heating and evaporation due to fire. **When its values are near one, we get smoother, PIC-like energy updates**, i.e. most particles which are near one another will have similar, pretty much the same energy and die at approximately the same time.

In practice, experiments showed that even relatively small values of $t$, values near but greater than $0$, already smooth the energies pretty strongly.

**The idea behind this blending is to make sure the energies are as grainy as possible to preserve details (smoothing causes the details to be lost) but to make them smooth enough so that as many particles as possible die at approximately the same time. We want the particles to die at the same time when interacting with fire because experiments showed that dying particles in general are the source of instabilities. If we make particles disappear one by one, it can cause particles to start moving very rapidly and even blow up sometimes. Experiments also showed that if we make them disappear in bigger groups, at similar moments, then they seem to be more stable.**

**One final reminder is that, for safety, we should perform particle energy update only when $\Delta H_{i} \gt 0$. This condition that energy should be updated only if $\Delta H_{i} \gt 0$ is actually pretty important. Let's remind ourselves that this condition is satisfied only when the temperature of fire is strictly greater than the maximum temperature of water. Because, in general, the temperature of fire is and should be greater than the maximum temperature of water, the regions where $\Delta H_{i} \gt 0$ actually represent the regions which are near fire, regions where fire is stronger and even visibly burning on screen. All other regions, in general, have some default ambient temperature equal to the ambient temperature of water.**

**Let's explain why this condition is important by assuming that we do not care about it the energy updates occur unconditionally. Energy updates based on the values read from *GP Grid*, in general, may not be accurate for a particle. In practice, the energy of the particle does not always change due to heat transfer between fire and water. When smoothing is involved, the energy can be updated even when no heat transfer occurs because of varying energy values of other particles in the nearest grid cells. This can both artificially loose and create energy.**

**This is why we want to limit ourselves and make the energy updates occur in both limited time and space. We want to take away the time for the inaccuracies to grow and we want to have as few inaccuracies as possible. So, we limit ourselves and turn on energy updates only in the regions near fire (limited space). We also know that fire-water interaction will be pretty rapid and particle will pretty quickly die (limited time). The idea is that those regions which are near fire are marked by the condition $\Delta H_{i} \gt 0$, as explained earlier, and are suppossed to be in general the regions where the fire is strong and visibly burning on screen.**

**All of this means that, even with smoothing, the energies of particles stay constant when the particles are far from fire. And it is important for them to stay constant (or to not increase uncontrollably, to be more precise) far from fire because otherwise we may get undesirable formation of vapor plumes as it will be described in more detail in the next section.**

And finally, we should also talk a little bit about $m_{i}^{\text{evap}}$ as this variable will be crucial in the next section for the modelling of vapor plumes. **We calculate it based on the change in the latent heat due to energy update**:

$$
m_{i}^{\text{evap}} = m \frac{H_{\text{latent},i}^{n} - H_{\text{latent},i}^{n - 1}}{E_{\text{vaporization}}}
$$

$$
H_{\text{latent},i}^{n} = \max(E_{i}^{n} - E_{\text{heating}}, 0)
$$

$$
H_{\text{latent},i}^{n - 1} = \max(E_{i}^{n - 1} - E_{\text{heating}}, 0)
$$

**It works like this. For particle $i$ we assume the full mass $m$ (which is constant and the same for all particles) if the particle $i$ satisfies $E_{i} \leq E_{\text{heating}}$. But if the particle $i$ satisfies $E_{i} \gt E_{\text{heating}}$ we assume a linear decrease in mass $m$. In other words, for $E_{i} \leq E_{\text{heating}}$ the mass of the particle is still $m$, for $E_{i} = E_{\text{max}}$ mass is $0$ and for values in between mass changes linearly. Or, shortly: mass decreases when latent heat increases.**

Note that $m$ is simply a scaling constant, so to avoid potentially really small numbers in the calculations we can assume the relationship given below and, if needed, use another, manually tuned, scaling constant later:

$$
m_{i}^{\text{evap}} = \frac{H_{\text{latent},i}^{n} - H_{\text{latent},i}^{n - 1}}{E_{\text{vaporization}}}
$$

**Also, it turns out that it is better to always use the same, unchanged constant mass $m$ for SPH particle calculations, instead of physically correct mass which decreases as latent heat increases. This is because experiments showed that using variable mass, i.e. mass that goes to zero, makes the particles unstable and they often blow up when their masses get smaller and smaller.**

## Vapor plumes formation

Another visual effect that we want to model is the formation of smoke-ish plumes which are suppossed to represent condensed water vapor and should appear when the water is evaporating, i.e. losing its mass.

To model this we take advantage of the existing fire/smoke subsimulation. It can already simulate the smoke which naturally forms during fires. We have much freedom in choosing  where this smoke appears, how big and aggressive it is and what color it has.

**As for condensed water vapor, we can also view it as a kind of smoke. The difference is that we assume that condensed water vapor is a highly specific type of smoke. We assume that it has a very light, white-ish color, is injected only when water is evaporating/loosing mass and its intensity depends on how much water is evaporating.**

**This basically means that we want to have two different types of smoke. The first one (the original one, the one that naturally forms during fires, the one which is already simulated by the original subsimulation) will be simply called "smoke". The second one (condensed water vapor) will be simply called "vapor".**

**What we can do is use the same algorithm for simulating both.**

**But we do not create another, separate subsimulation just to simulate vapor as this would be inefficient.**

**Instead, we introduce a new variable to the smoke algorithm. Let's call this variable $\rho_{\text{vapor}}$, $0 \leq \rho_{\text{vapor}} \leq 1$. We can interpret it as the density of vapor or as a fuzzy boolean variable which tells us how "vapor-ish" smoke is or as the strength of the "vaporness" of smoke at any given region. Its main role is to help visually distinguish vapor from smoke using a white-ish color, and to blend this white-ish color with the normal smoke's color.**

**This variable is a new eulerian grid variable and is updated according to:**

$$
\frac{d\rho_{\text{vapor}}}{dt} = -(\mathbf{u}_{\text{smoke}} \cdot \nabla)\rho_{\text{vapor}} + k_{\text{vapor,density}}^{\text{inject}}m_{\text{pg}}^{\text{evap}}\rho_{\text{pg}}
$$

**The blending between smoke color and vapor color is done according to:**

$$
C_{\text{final}} = (1 - \rho_{\text{vapor}})C_{\text{smoke}} + \rho_{\text{vapor}}C_{\text{vapor}}
$$

**Each timestep the injection term also contributes to the smoke density $\rho_{\text{smoke}}$ so that the vapor can appear on screen:**

$$
\rho_{\text{smoke}}^{\text{new}} = \rho_{\text{smoke}} + k_{\text{vapor,density}}^{\text{inject}}m_{\text{pg}}^{\text{evap}}\rho_{\text{pg}}dt
$$

**Each timestep the injection term also contributes to the smoke temperature $T_{\text{smoke}}$ so that the vapor can either quickly rise up or slowly fall down:**

$$
T_{\text{smoke}}^{\text{new}} = T_{\text{smoke}} + k_{\text{vapor,temperature}}^{\text{inject}}m_{\text{pg}}^{\text{evap}}\rho_{\text{pg}}dt
$$

Here $m_{\text{pg}}^{\text{evap}}$ and $\rho_{\text{pg}}$ are the values that smoke reads from *PG Grid*. Moving on, $k_{\text{vapor,density}}^{\text{inject}}$ is a tunable parameter controlling the strength of injection of $\rho_{\text{vapor}}$. Finally, $k_{\text{vapor,temperature}}^{\text{inject}}$ is also a tunable parameter which controls the strength of vapor's temperature injection.

Additionally, even though it is not stated in the above equations, **$\rho_{\text{vapor}}$ should dissipate with the same rate as $\rho_{\text{smoke}}$**.

The equations above are suppossed to encode **the following behaviors of vapor**:

* $\rho_{\text{vapor}}$ is advected along the smoke's velocity field so that we can keep track of which regions are smoke vs which regions are vapor so that we can color them appropriately
* the injection and dissipation of $\rho_{\text{vapor}}$ helps blend between the two colors naturally
* the injection contribution to $\rho_{\text{smoke}}$ causes the vapor to appear (density injection)
* the injection contribution to $T_{\text{smoke}}$ causes the vapor to start moving due to buoyancy (temperature injection)
* the injection works only when there is some water in the cell and only when this water is evaporating, i.e. only when $m_{\text{pg}}^{\text{evap}}\rho_{\text{pg}} \gt 0$
* the more evaporating water there is in the cell, the more density and temperature is injected, i.e. more evaporating water = more vapor; the term responsible for this is the product $m_{\text{pg}}^{\text{evap}}\rho_{\text{pg}}$, it was found experimentally and turned out to give this desired behaviour

Based on the above we can now explain why the condition $\Delta H_{i} \gt 0$ is important for the formation of vapor. Let's remind ourselves that this condition is used to ensure that particle energies are updated only near the regions of strong/visible fire. Far from fire the energies of particles are not updated. **Because evaporated masses are calculated based on changes in latent heats, and changes in latent heats are directly related to changes in energy, this means that far from fire evaporated masses will always stay constant, they will always stay zero in our case. In other words, the mass will only evaporate near the fire, where the heat transfer occurs.**

This is a crucial assumption because, as we explained earlier, inaccuracies that arise when using *GP Grid* can cause undesirable updates of energies and therefore undesirable changes in latent heats. **Because of these undesirable changes,  evaporated masses will appear when we do not want them and will give us wrong visual effects of vapor appearing when it should not and in quantities that are not correct.** By ensuring that energies change only near the regions of fire, we make the assumption that water only evaporates near fire which is a simplification but provides more control over the visual effects of the simulation.

**There is one important limitation of the approach with $\rho_{\text{vapor}}$** described here. If we used a separate smoke subsimulation (i.e. with separate variables, e.g. velocity) to simulate vapor, thus completely decoupling vapor from smoke, we would have full control over vapor. **By using the same existing subsimulation for both smoke and vapor, we loose a little bit of control over vapor.** This is because both smoke and vapor use the same velocity field. For example, when we have (1) a predefined smoke which moves quickly upwards and (2) a vapor that is tuned to move slowly downwards when injected, we get the desired vapor behavior only in the regions where there is no smoke whatsoever. In the regions where there is some smoke and there is some vapor, i.e. where the two blend, the big velocity of smoke is visually inherited by vapor as the variable $\rho_{\text{vapor}}$ is advected along the very quick velocity field near the smoke region. This gives the visual result of vapor moving quickly with smoke even though we specified vapor to be slow.

## Flame extinguishing

Final visual effect that we want to model is fire extinguishing upon interacting with water.

There are many approaches that we can take but the one that turned out to work the best in practice is the approach described below.

**The first thing we do is we change the combustion model a little bit. This is because the original model overwrites fire's temperature in each frame by using the max function:**

$$
T_{\text{fire}} = \text{max}(T_{\text{fire}}, \rho_{\text{fuel}} T_{\text{burn}})
$$

Instead, **we would like to have a model where each variable is updated using the timestep, as this helps in modelling continuous changes of variables naturally**, like gradual extinguishing or gradual reignition.

**This is why we modify the above equation and use it to define the injection term of fire's temperature:**

$$
\left(\frac{dT_{\text{fire}}}{dt}\right)_{\text{inject}} = k_{\text{fire}}^{\text{release}} \rho_{\text{fuel}} T_{burn}
$$

Here $k_{\text{fire}}^{\text{release}}$ is a tunable parameter defining how fast the heat is introduced into the system by the fuel.

**With this change in place, we can now model the responsiveness of fire's temperature to the heat stolen by water particles:**

$$
\left(\frac{dT_{\text{fire}}}{dt}\right)_{\text{water,drop}} = - k_{\text{fire,temperature}}^{\text{drop}} \Delta H_{\text{gp}}
$$

Here $k_{\text{fire,temperature}}^{\text{drop}}$ is another tunable parameter which defines how strongly fire is cooled when it contacts water. As for $\Delta H_{\text{gp}}$, it is the amount of heat transfer from fire to water in the current cell and fire reads it from *GP Grid*.

The above is just used to provide visual feedback, it is not the mechanism of extinguishing. The exitnguishing is done not by attacking the temperature of fire but by attacking the fuel injection mask. Fuel injection mask provides fuel, fuel provides temperature and temperature provides visual fire. So, **removing fuel injection mask should directly remove visual fire**.

Our approach is to **introduce a new eulerian grid variable, an extinguish mask $M_{\text{ext}}$, $0 \leq M_{\text{ext}} \leq 1$**. When $M_{\text{ext}} = 0$, it means that fire in the given region is not extinguished. When $M_{\text{ext}} = 1$, it means that fire in the given region is completely extiguished. Values in between blend linearly between the two edge cases.

With extinguish mask we can alter the equation for fuel injection so that **the more fire is extinguished in the given region, the less fuel is injected there and thus less temperature is injected there and therefore visual fire becomes weaker there**:

$$
(\frac{d\rho_{\text{fuel}}}{dt})_{\text{inject}} = (1 - M_{\text{ext}}) k_{\text{fuel,inject}}
$$

Here $k_{\text{fuel,inject}}$ is the constant fuel inject rate painted by the fuel brush.

**Extinguish mask itself is initialized to zero at the very beginning. It can be updated, i.e. increased or decreased, but only in the regions where the painted fuel mask is non-zero, i.e. in places where there is a continuous fuel injection rate specified. When water interacts with fire, extinguish mask is increased with some rate dependent on the water properties. In this way we can model gradual extinguishing. To model gradual reignition we also make extinguish mask decrease on its own. In other words, water pushes extinguish mask to reach $1$ while fire pushes extinguish mask to reach $0$. We assume that if water is strong enough to "beat" fire and make extiguish mask reach the value of $1$ in the given region, then fire is extinguished there and stays extinguished until we e.g. reset the simulation with a key press. That is, when extinguish mask reaches the value of $1$, it is no longer increased nor decreased, it stays at this value, and the fire in this region is extinguished, until manual reset.**

The rate at which water extinguishes fire is modelled using three phenomena.

**The first one is cooling** which is modelled as the difference between fire temperature before, $T_{\text{fire,before}}$, and fire temperature after, $T_{\text{fire,after}}$, temperature drop due to water, $\left(\frac{dT_{\text{fire}}}{dt}\right)_{\text{water,drop}}$, has been applied. The bigger the cooling, the stronger the extinguishing:

$$
\left( \frac{dM_{\text{ext}}}{dt} \right)_{\text{cool}} = k_{\text{cool}} (T_{\text{fire,before}} - T_{\text{fire,after}})
$$

**The second one (the most important one) is vaporization.** We reuse the same term, $m_{\text{pg}}^{\text{evap}}\rho_{\text{pg}}$, as in the case of vapor formation. The bigger the evaporation, the stronger the extinguishing:

$$
\left( \frac{dM_{\text{ext}}}{dt} \right)_{\text{evap}} = k_{\text{evap}} m_{\text{pg}}^{\text{evap}}\rho_{\text{pg}}
$$

**The third one, I am not sure how to call it, is an auxiliary term.** We use it because the previous two terms are indirectly dependent on the heat transfer from fire to water which itself is directly dependent on whether the temperature of fire is above the boiling temperature of water. This means that the more the fire gets extinguished and the more it lowers its temperature, the heat transfer from fire to water gets smaller and smaller which finally makes the two extinguishing terms above smaller and smaller. In the end it just means that with the above two terms it is hard to extinguish weak fires and achieve 100\% extinguish mask overlayed on the fuel mask.

To counteract this, we introduce an auxiliary extinguishing term which is non-zero only if there is some water present in the given cell. This auxiliary term becomes relevant (i.e. gets values significantly greater than zero) when the previous two terms become irrelevant (i.e. approach zero). It is suppossed to turn on mainly when the main fire has already been extinguished but there are still some regions of fuel mask that have not been properly extinguished by the previous two terms. It makes it possible to extinguish them and achieve nice and clean 100% extinguishing. The formula encoding this behaviour that proved to work well is (the number one in the denominator is used to prevent divisions by zero):

$$
\left( \frac{dM_{\text{ext}}}{dt} \right)_{\text{aux}} = \frac{k_{\text{aux}}\rho_{\text{pg}}}{\left( \frac{dM_{\text{ext}}}{dt} \right)_{\text{cool}} + \left( \frac{dM_{\text{ext}}}{dt} \right)_{\text{evap}} + 1}
$$

**The rate at which fire reignites on its own is given by:**

$$
\left( \frac{dM_{\text{ext}}}{dt} \right)_{\text{reig}} = -k_{\text{reig}}
$$

Parameters $k_{\text{cool}}$, $k_{\text{evap}}$, $k_{\text{aux}}$, $k_{\text{reig}}$ are tunable parameters.

The total rate of change of extinguish mask is then:

$$
\frac{dM_{\text{ext}}}{dt} = \left( \frac{dM_{\text{ext}}}{dt} \right)_{\text{cool}} + \left( \frac{dM_{\text{ext}}}{dt} \right)_{\text{evap}} + \left( \frac{dM_{\text{ext}}}{dt} \right)_{\text{aux}} + \left( \frac{dM_{\text{ext}}}{dt} \right)_{\text{reig}}
$$

The end.

# The algorithm

Below is the simplified pseudocode for the fire extinguishing simulation:

```python
while true:

    # Update fire, then water
    # I guess it could also be the other way around
    fire_smoke_update(dt)
    water_update(dt)

    # Render:
    # - fire using a lookup texture (Plack's Law)
	# - smoke using its density
    # - the blend of fire and smoke using their color components
    # - water using the smoothed density field obtained from the texture which stores positions of particles
	render_fire()
    render_smoke()
    render_fire_smoke_blend()
    render_water(blur(texture))
```

```python
fire_smoke_update(dt):

    # 1. Read particle properties from PG Grid
    rho_pg, e_pg, m_evap_pg = read_pg()

	# 2. Advect velocity fields (move velocity along itself)
	fire_velocity = advect(fire_velocity, fire_velocity, dt)
    smoke_velocity = advect(smoke_velocity, smoke_velocity, dt)

    # 3. Draw/Erase splash masks using brushes/erasers
    draw_erase(fire_fuel_mask)
    draw_erase(smoke_density_and_heating_mask)
    draw_erase(smoke_cooling_mask)

    # 4. Splash fire fuel, vapor density and smoke density
    fire_fuel += splash_fire_fuel(fire_fuel_mask, extinguish_mask, dt)
    delta_vapor_density = splash_vapor_density(rho_pg, m_evap_pg, dt)
    vapor_density += delta_vapor_density
    smoke_density += delta_vapor_density
    smoke_density += splash_smoke_density(smoke_density_and_heating_mask, dt)

    # 5. Add fire temperature, vapor temperature and smoke temperature
	fire_temp += add_fire_temp(fire_fuel, dt)
    smoke_temp += add_vapor_temp(rho_pg, m_evap_pg)
	smoke_temp += add_smoke_temp(smoke_density_and_heating_mask, dt)

    # 6. Dissipate fire fuel, vapor density and smoke density
    fire_fuel -= dissipate_fire_fuel(fire_fuel_dissipation_rate, dt)
    vapor_density -= dissipate_smoke_density(smoke_density_dissipation_rate, dt)
    smoke_density -= dissipate_smoke_density(smoke_density_dissipation_rate, dt)

    # 7. Dissipate fire temperature and smoke temperature
	fire_temp -= dissipate_fire_temp(fire_temp_cool_rate, dt)
	smoke_temp -= cool_smoke_temp(smoke_temp_cool_rate, dt)
    smoke_temp -= cool_smoke_temp(smoke_cooling_mask, dt)

    # 8. Write particle properties to GP Grid
    d_e_gp, e_new_gp, d_h_gp, rho_gp = update_water_energy(fire_temp, rho_pg, e_pg)

    # 9. Drop fire temperature due to its interaction with water and store the drop
    fire_temp_drop = drop_due_to_water(d_h_gp, dt)
    fire_temp -= fire_temp_drop

    # 10. Update extinguish mask (increasing = extinguishing, decreasing = reignition)
    cool_contribution = get_cool_contribution(fire_temp_drop)
    evap_contribution = get_evap_contribution(rho_pg, m_evap_pg)
    aux_contribution = get_aux_contribution(rho_pg, cool_contribution, evap_contribution)
    extinguish_mask += incr_extinguish_mask(cool_contribution, evap_contribution, aux_contribution, dt)
    extinguish_mask -= decr_extinguish_mask(extinguish_mask < 1.0, reignition_rate, dt)

	# 11. Apply external forces
	fire_velocity += apply_forces(fire_external_forces, dt)
	smoke_velocity += apply_forces(smoke_external_forces, dt)

	# 12. Set boundary conditions for velocities
	fire_velocity = set_velocity_boundaries(fire_velocity)
    smoke_velocity = set_velocity_boundaries(smoke_velocity)

	# 13. Compute divergences of velocity fields
	fire_divergence = compute_divergence(fire_velocity)
    smoke_divergence = compute_divergence(smoke_velocity)

	# 14. Solve Poisson equations for pressure using Jacobi method
	fire_pressure = solve_pressure_poisson(fire_divergence, iterations)
    smoke_pressure = solve_pressure_poisson(smoke_divergence, iterations)

	# 15. Set boundary conditions for pressures
	fire_pressure = set_pressure_boundaries(fire_pressure)
    smoke_pressure = set_pressure_boundaries(smoke_pressure)

	# 16. Subtract pressure gradients to enforce incompressibility
	fire_velocity = subtract_gradient(fire_velocity, fire_pressure)
    smoke_velocity = subtract_gradient(smoke_velocity, smoke_pressure)

	# 17. Advect temperatures along the corresponding velocity fields
	fire_temp = advect(fire_temp, fire_velocity, dt)
    smoke_temp = advect(smoke_temp, smoke_velocity, dt)
    
	# 18. Advect fire fuel, smoke density and vapor density along the corresponding velocity fields
	fire_fuel = advect(fire_fuel, fire_velocity, dt)
    smoke_density = advect(smoke_density, smoke_velocity, dt)
    vapor_density = advect(vapor_density, smoke_velocity, dt)
```

```python
water_update(dt):

	# 1. Read particle properties from GP Grid
    for particle in particles:
        read_gp_1 = [d_e_gp_1, e_new_gp_1, d_h_gp_1, rho_gp_1] = read_gp(gp_neighbor_1)
        read_gp_2 = [d_e_gp_2, e_new_gp_2, d_h_gp_2, rho_gp_2] = read_gp(gp_neighbor_2)
        read_gp_3 = [d_e_gp_3, e_new_gp_3, d_h_gp_3, rho_gp_3] = read_gp(gp_neighbor_3)
        read_gp_4 = [d_e_gp_4, e_new_gp_4, d_h_gp_4, rho_gp_4] = read_gp(gp_neighbor_4)
        d_e, e_new, d_h = bilerp_weighted_sum(read_gp_1, read_gp_2, read_gp_3, read_gp_4)
        new_energy = update_energy(old_energy, d_e, e_new, d_h, lerp_factor)
        energy = new_energy
        evaporated_mass = get_evaporated_mass(new_energy, old_energy)
    
    # 2. Increase ages
    increase_ages()

    # 3. Kill particles that reached their energy limits or reached their lifetime limits
	kill_particles(energies, ages)

	# 4. Spawn new particles (initialize their properties)
	spawn_particles()

	# 5. Neighborhood search
	hashes = compute_hashes()
    sorted_hashes, sorted_positions = sort(hashes, positions)
    start, end = compute_start_end(sorted_hashes)

	# 6. Compute densities
	densities = compute_densities()

    # 7. Compute near densities
    near_densities = compute_near_densities()

	# 8. Compute pressures
	pressures = compute_pressures()

    # 9. Compute near pressures
    near_pressures = compute_near_pressures()

	# 10. Compute vorticities
	vorticities = compute_vorticities()

	# 11. Compute forces
    forces = 0
	forces += compute_pressure_force()
    forces += compute_near_pressure_force()
    forces += compute_viscosity_force()
    forces += compute_gravity_force()
    forces += compute_user_disturbance_force()
    forces += compute_surface_tension_force()
    forces += compute_vorticity_confinement_force()

	# 12. Compute acceleration
    a = compute_acceleration(forces, densities)

    # 13. Compute adhesive acceleration
    for sdf in sdfs:
        a += compute_adhesive_acceleration(sdf)

    # 14. Integrate velocities
	velocities = integrate(velocities, dt)

    # 15. Apply XSPH smoothing
    velocities = xsph(velocities)

    # 16. Damp and clamp velocities
    velocities = damp(velocities)
    velocities = clamp(velocities)

    # 17. Integrate positions
    positions = integrate(positions, dt)

    # 18. Perform SDF collision responses
    for sdf in sdfs:
        positions, velocities = collide_using_sdf(sdf, positions, velocities)

    # 19. Boundary conditions
    positions, velocities = boundary_conditions(positions, velocities)

    # 20. Write particle properties to PG Grid (gather particle contributions)
    for cell in pg_grid:
        rho_pg_sum = 0
        e_pg_sum = 0
        m_evap_pg_sum = 0
        for particle in cell_neighbors:
            w = get_bilerp_weight(particle_position, cell_center_position)
            rho_pg_sum += w
            e_pg_sum += w * particle_energy
            m_evap_pg_sum += w * particle_evaporated_mass
        rho_pg = rho_pg_sum
        e_pg = e_pg_sum / rho_pg
        m_evap_pg = m_evap_pg_sum / rho_pg

	# 21. Store the positions in the texture for rendering purposes
    store_positions(positions, texture)
```
