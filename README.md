# Introduction

This project is a 2D, real-time, physics-based fire extinguishing simulation running on the GPU.

It consists of two subsimulations: my fire/smoke simulation (https://github.com/Kamil-Kochanczyk/Fire-Smoke) and my water simulation (https://github.com/Kamil-Kochanczyk/Fluid-Smoke-Fire-Water). They both work together to produce three visual effects when water particles start interacting with fire/smoke grid: water disappearing, smoke/vapor plumes forming, fire dying.

To learn more about the subsimulations, check the above links as they will not be described here. Here we will only talk about how to expand them so that they communicate and interact with each other to simulate fire extinguishing.

# Fire extinguishing model

## Physical basis

First, some guiding physical facts:
* Evaporating water looses its mass and disappears because it becomes a gass, i.e. vapor.
* Vapor itself is invisible but after some time has passed since evaporation, this invisible gas condenses into visible smoke-ish plumes.
* Heat loss is the main reason why water can extinguish fire so well. Heating and, especially, vaporization of water requires enormous amounts energy to be delivered. When water appears near fire, fire looses much of its energy to heat and vaporize water. If fire energy becomes sufficiently small, then the fire cannot sustain itself and dies.

## Painting

Fire and smoke in the fire/smoke subsimulation can only appear on screen continuously (without immediately disappearing) if they have continuous predefined sources. A good idea is to be able to "draw" and/or "erase" them on screen using "brushes" and/or "erasers" as if in a graphics editor. This allows to create fire and smoke in any place on screen, tweak their sizes, strength, location etc.

We thus extend the algorithm of the origianl fire/smoke subsimulation. We add the possibility to define several variables by drawing/erasing them on screen with brushes/erasers. Those variables are:

* fire fuel injection rate $(\frac{d\rho_{\text{fuel}}}{dt})_{\text{inject}}$ which contributes to the fire fuel's rate of change $\frac{d\rho_{\text{fuel}}}{dt}$
* smoke density injection rate $(\frac{d\rho_{smoke}}{dt})_{\text{inject}}$ which contributes to the smoke density's rate of change $\frac{d\rho_{smoke}}{dt}$
* smoke temperature heating injection rate $(\frac{dT_{\text{smoke,h}}}{dt})_{\text{inject}}$ which contributes to the smoke temperature's rate of change $\frac{dT_{\text{smoke,h}}}{dt}$
* smoke temperature cooling injection rate $(\frac{dT_{\text{smoke,c}}}{dt})_{\text{inject}}$ which contributes to the smoke temperature's rate of change $\frac{dT_{\text{smoke,c}}}{dt}$.

Each variable gets its own brush and eraser. We assume that $(\frac{d\rho_{smoke}}{dt})_{\text{inject}}$ and $(\frac{dT_{\text{smoke,h}}}{dt})_{\text{inject}}$ are edited with the same brush/eraser. This gives us three brushes and three erasers in total, one for each variable.

Every brush/eraser has its strength and radius which can be changed at any time. Wherever we draw a variable, its value there becomes non-zero and, depending on the strength and radius of the brush, we can draw big and strong fires and smokes which quickly heat in some regions and quickly cool in other regions. Eraser works in the opposite way, i.e. it makes the value of the variable go towards zero and can make fire and smoke more subtle both visually and in movement.

## Eulerian-Lagrangian communication
Since fire/smoke uses eulerian grids and water uses lagrangian particles, we need to find a way for both to communicate with each other, i.e. exchange information such as variables.

This is done by introducing two new grids. To differentiate them from the eulerian grids used to simulate fire and smoke let's call them communication grids.

The first communication grid, let's call it PG, is used for (lagrangian particles -> eulerian grid) communication. In other words, water particles write their properties to this grid so that fire/smoke can later read them. For example, if each particle stored its current temperature, PG grid would allow fire/smoke to sample this PG grid to estimate/approximate the temperature of particles in each fire/smoke eulerian grid cell.

The second communication grid, let's call it GP, is used for  (eulerian grid -> lagrangian particles) communication. It is the opposite of PG grid, i.e. water particles read some properties from this grid while fire/smoke writes some properties to this grid. For example, if fire/smoke were suppossed to increase/decrease the temperature of particles, it would first read their current temperature from PG grid, apply some delta to it, and save the updated values in GP grid so that particles can later read them and therefore update their temperatures.

 We choose to set both PG and GP grids to have the same size. This size can actually be different from the size of the eulerian grids used in the origianl fire/smoke subsimulation.
 
 Since the communication grids are grids, reading from them and writing to them does not pose any problems to fire/smoke eulerian grids (we just use simple samplers).

 However, a bigger problem is with water particles. There are a few ideas as to how water particles can read from or write to the communication grids but one solution that proved to work the best (i.e. solution which is the most accurate and most resistant to numerical dissipation) is the weighted sums with bilinear interpolation weights (because we work in 2D).

 To be more precise, when a particle wants to write its property to PG grid, it distributes this property to the four neighboring grid cells (grid cell centers) using bilinear interpolation weights.

 The bilinear interpolation weights in the normalized square are:

 $$w_{1} = (1 - u)(1 - v)$$
 $$w_{2} = u(1 - v)$$
 $$w_{3} = (1 - u)v$$
 $$w_{4} = uv$$

 Those can actually be written using one formula dependent on the horizontal distance $d_{x}$ and vertical distance $d_{y}$ between the particle $j$ and the given grid cell $i$ (grid cell's center):

 $$w_{ij} = (1 - d_{x})(1 - d_{y})$$

 This means that instead of performing bilinear interpolation scattering for each particle, we can perform bilinear interpolation gathering for each PG grid cell. It allows us to avoid atomic operations and race conditions between multiple particles wanting to write their contribution to the same PG grid cell.
 
 The only thing we need to do is to find the closest, neighboring particles for each PG grid cell, i.e. their neighborhoods. The neighborhood of a PG grid cell is defined as all particles falling within the distance of 1 pixel (or 1 texel) from the given PG grid cell. This is because only those particles will have the given PG grid cell as one of their four neighbors to which they will contribute their properties. To find the neighborhood of each PG grid cell we take advantage of the neighborhood search grid used in the water subsimulation to find the neighborhood of each particle. However, the neighborhood of a particle and the neighborhood search grid are defined differently (using the smoothing radius $h$). This means that we have to map the neighborhood search grid to the PG grid, i.e. find their intersection around the given PG grid cell, to efficiently find all particles contributing to the given PG grid cell.

 Using the bilinear interpolation weight $w$, in each frame, a PG grid cell $i$ therefore gathers the properties from its neighboring particles $j$ so that fire/smoke can later read those properties and do something based on them: density $\rho_{\text{pg},i}$, energy $E_{\text{pg},i}$ and evaporated mass $m_{\text{evap,pg},i}$.

 Density is calculated for each PG grid cell as follows:

 $$
\rho_{\text{pg},i} = \sum_{j \in N(i)} w_{ij}
 $$

 Energy is calculated as follows:

 $$
E_{\text{pg},i} = \frac{\sum_{j \in N(i)} w_{ij}E_{j}}{\rho_{\text{pg},i}}
 $$

Evaporated mass is calculated as follows:

 $$
m_{\text{evap,pg},i} = \frac{\sum_{j \in N(i)} w_{ij}m_{\text{evap},j}}{\rho_{\text{pg},i}}
 $$

Since we assumed the same sizes of PG and GP grids, we also have $\rho_{\text{gp},i} = \rho_{\text{pg},i}$, $E_{\text{pg},i} = E_{\text{gp},i}$, $m_{\text{evap,pg},i}$, i.e. the values from PG grid can be directly passed to GP grid.

 When a particle wants to read some property from GP grid, it similarly performs the weighted sum with bilinear interpolation weights. This is simple as it just requires finding the nearest four neighboring GP grid cells for each particle and use the weights $w_{1}, w_{2}, w_{3}, w_{4}$ to calculate the desired property.

 In each frame, the properties that are written by fire/smoke to a GP grid cell $i$ and read later by water are the following four properties: delta particle energy $\Delta E_{\text{gp},i}$, new (modified, updated) particle energy $E_{\text{gp,new},i}$, heat transfer amount from fire to water $\Delta H_{\text{gp},i}$ and finally particle density $\rho_{\text{gp},i}$.

 $\Delta E_{j}$, $E_{\text{new},j}$ and $\Delta H_{j}$ are calculated by each particle $j$ using the same weighted sum formula below:

 $$
q_{j} = \frac{w_{1}q_{\text{gp,1}} + w_{2}q_{\text{gp,2}} + w_{3}q_{\text{gp,3}} + w_{4}q_{\text{gp,4}}}{w_{1} + w_{2} + w_{3} + w_{4}}
 $$

Here $q_{j}$ denotes one of the three beforementioned quantities while $q_{\text{gp,1}}, q_{\text{gp,2}}, q_{\text{gp,3}}, q_{\text{gp,4}}$ denote the quantities of the four surrounding GP neighbors of the particle.

As for particle density we have $\rho_{\text{gp},i} = \rho_{\text{pg},i}$. Particle density in case of GP grid is used to discard those GP grid cells which do not containg any particle, i.e. those GP grid cells where $\rho_{\text{gp},i} = \rho_{\text{pg},i} = 0$. We discard such grid cells from the weighted sum as we assume that wherever there are no particles, their properties are undefined there. Moreover, not discarding such grid cells would cause problems with numerical dissipation.

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

## Flame extinguishment

Now, we assume that the fire in the given region is extinguished if its temperature falls below some predefined threshold $T_{\text{extinguish}}$. If this condition is satisfied in the given region, the boolean extinguish mask is set to true in that region and prevents the temperature from being injected in this region. This mask is set only in those places where the fuel inject rate $\frac{d\rho_{\text{fuel}}}{dt}$ is non-zero. However, in order for this to work, the original fire model needs to be tweaked a little bit. In the fire/smoke subsimulation, the fire constantly overwrites its temperature using the max function in the equation $T = \text{max}(T, \rho_{\text{fuel}} * T_{\text{burn}})$. This needs to be changed into a continuous update scheme using the derivative of the temperature so that the fire and water can "wrestle" to see whether water is strong enough to drop fire's temperature sufficiently, i.e. below the extinguishing threshold. Thus, the new equation is $\frac{dT}{dt} = \rho_{\text{fuel}} \cdot T_{burn} \cdot k_{\text{release}}$, where $k_{\text{release}}$ is a tunable constant defining how fast the heat is introduced into the system by the fuel. Another thing to keep in mind is that the fire naturally cools down due to fuel and temperature dissipation. This means that we need to somehow differentiate between "natural fire cooling" and "fire cooling due to water". One simple solution for this is to track two instances of the same fire: one which reacts to water and one which does not react to water. In order to say whether the extinguishing occurred or not, we compare the temperature of the fire which reacts to water to the temperature of the fire which does not react to water. This may allow us to see the temperature of the fire "as if there was not any water" to find regions which are suppossed to have high temperatures but for some reason have low temperatures (this reason is assumed to be the water which "steals" the temperature from the fire). However, this approach is not implemented because it is not effective and requires additional fire subsimulation to be performed along the existing fire/smoke and water subsimulations. Therefore, we do an approximate but simpler idea. We note that fire fuel is not affected by the extinguish mask generally follows the same steps during its lifetime as fire temperaturem, i.e. looking at the visualized fuel and temperature, they look similar. We can thus tune a fire fuel threshold, $\rho_{\text{vis}}$, and the idea is that regions where $\rho_{\text{fuel}} > \rho_{\text{vis}}$ indicate the regions where the fire temperature is suppossed to be high enough so that we can see it and much higher than the extinguish threshold. And we extinguish only such regions. This approach is only approximation and can pose problems with total (100%) fire extinguishment (as there can be regions where the fuel does not satisfy this condition and temperature is indeed still injected there) but it is cheap and can give desired results with appropriate parameter tuning.
 