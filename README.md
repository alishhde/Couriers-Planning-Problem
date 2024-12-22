# Multiple Couriers Planning Problem
It has become more common recently, especially after the outbreak of the COVID-19 pandemic, to send or receive items online (e.g., food, goods, clothes, documents). Hence, it is more and more important for companies to efficiently schedule the dispatching of items through different couriers to minimize the transportation costs. 
<div align='center'><img src='MCP_image.png'></img></div>

Regarding this, in this project we will formulate the Multiple Courier Planning Problem. Here's the definition of the problem. ⤵️

> We have  couriers that must distribute  items at different customer locations. Each courier  has a maximum load size . Each item  has a distribution point  and a size . The goal of MCP is to decide for each courier, the items to be distributed and plan a tour (i.e. a sequence of location points to visit) to perform the necessary distribution tasks. Each courier tour must start and end at a given origin point . 
> 
> Moreover, the maximum load  of the courier  should be respected when items are assigned to it. To achieve a fair division among drivers, the objective is to minimize the maximum distance travelled by any courier. 
>

Since item number equals the city number, we don't need to formulate the city, and we have to only formulate the assignment of the items to couriers with respect to the sizes and capacities. Then, we need to minimize the maximum distance being traveled by a courier. Consequently, a correct formulation aside from the minimization goal helps us to achieve the best permutation of the assignment of the items.

## Modelings
### 1st Formulation (3-Dimensional Arc-Based Matrix)
In the initial modeling approach we implemented a 3D boolean matrix, $path_{i,j,k}$, where each entry indicates whether courier $k$ travels from item $i$ to item $j$. This representation effectively demonstrated paths for smaller instances, but struggled with scalability as the number of couriers and items increased. For larger instances, it often failed to find any solution within a reasonable time.

<br>

### 2nd Formulation (Reduced-Dimension Arc-Based Matrix)
To mitigate the scalability issues, the second modeling reduced the dimensionality by having one dimension of the matrix, couriers, as the domain, resulting in a 2D matrix $path_{i,j}$ with values representing which courier travels from item $i$ to $j$. Although this significantly cut down on the number of variables and improved computational speed, it did not sufficiently enhance the quality of solutions for larger instances. The model could find solutions for slightly larger instances than before but still struggled to reach near-optimal solutions for large instances.

<br>

### 3rd Formulation (Couriers-by-Distribution Points Matrix with Arc-Based Approach)
Considering that in the real world, the number of couriers is typically smaller than the number of items, the third approach reorganized the matrix to have couriers as rows and distribution points as columns. Each variable, $sequence_{k,n}$ represented which distribution point $n$ courier $k$ would go to next. 

<br>

### 4th Formulation (Heuristic with Maximum Item Constraints)
Recognizing the inherent complexity of the problem, the fourth modeling incorporated a heuristic-based approach. A practical assumption was introduced: each courier could have a maximum path length, $max\\_pl$, of size $\left\lceil  \frac{num\\_item}{num\\_courier}  \right\rceil + 2$. Considering this new heuristic approach, we re-implemented the previous modeling with the new length for the column. This new sequence matrix is now of dimension $num\\_courier \space * \space max\\_pl$ where each entry takes a value pointing to a distribution point and different than previous modelings, in this modeling a path is defined as the consecutive cities that are gathered consecutively in this new matrix of $sequence$.

While these assumptions may not hold for every scenario, they enabled the solver to find good solutions more quickly, demonstrating that heuristic approaches are often necessary to handle large-scale real-world instances.

In the following, we take a look at this last modeling more in detail describing the variables, and the constraints and the experimental parts.

<br><br>

## Decision Variables 
Let's see how this last model is implemented.
- **traveled_distance** (`array[couriers] of var int`) <br>
	This variable records the total distance traveled by each courier.
	- Defined per courier, it aggregates the distances corresponding to that courier’s assigned route.
	- The solver will determine values that minimize these distances, or incorporate them into objective functions or constraints, depending on the model’s goals.
- **bin** (`array[items] of var couriers`) <br>
	This variable assigns each item to exactly one courier.
	- For every item, the variable takes on a courier’s index as a value, indicating which courier is responsible for delivering that item.
	- The solver chooses these assignments in a way that satisfies capacity, route feasibility, or fairness constraints and contributes to an optimal or near-optimal solution.
- **sequence** (`array[couriers, num_nodes] of var 0..num_points`) <br>
	This variable defines the visiting order of distribution points for each courier.
	- Each courier has a sequence of nodes they will visit, where each entry in the sequence array represents the next distribution point on that courier’s route.
	- The indexing set, **num_nodes**, is chosen as a fixed upper bound on the maximum route length: <br>
  	$$max\\_pl = \lceil \frac{num\\_item}{num\\_courier} \rceil + 2.$$ <br>
	 This ensures enough “slots” to accommodate each courier’s entire route, including depot visits, however, it also oblige each courier to not take items more than this defined `max_pl` which may not be correct in all the cases.
	- `0` is used to deactivate variables that solver must not travers.
- **length_of_path** (`array[couriers] of var 3..max_pl`) <br>
	This variable specifies the actual number of nodes used in each courier’s route.
	- The domain starts at 3 to ensure that each courier’s route includes at least a start depot, at least one item, and an end depot.
	- By setting this variable, the model can differentiate between allocated route “slots” (in **sequence**) and the actual length of the route.
	- During optimization, this helps enforce minimum route requirements and ensures each courier is assigned at least one item.

<br>

These decision variables work together to determine how items are allocated to couriers, the sequence of visits for each courier, and the associated distances traveled. The **bin** variable controls item-to-courier assignments, the **sequence** array and **length_of_path** variables govern the exact ordering and number of stops each courier makes, and the **traveled_distance** variable measures how costly these choices are in terms of travel distance.

## Objective and Boundaries on Traveled Distance
In this problem our objective is to minimize the maximum traveled distance by any courier.  

- Objective-Related Variable (max_route_found ($max\\_route\\_found$)) <br>
	$$max\_route\_found = \max({ traveled\_distance[c] \mid c \in couriers })$$
	This variable captures the longest distance traveled by any courier. By focusing on this maximum value, the solver can aim to reduce the disparity between couriers’ workloads and minimize the overall maximum route length.

- lb ($lb$) <br>
	$$lb = \max({ distance\_mat[num\_points, i] + distance\_mat[i, num\_points] \mid i \in items })$$
	This represents a lower bound on the minimum travel distance required. It is derived from the longest single round trip from the depot to an item and back. No courier can have a route shorter than this value if they are assigned at least one item.

- consecutive ($consec$) <br>
	$$consec = \sum_{i = 1}^{1..(num\\_item-1)} distance\\_mat[i, i+1]$$  <br>
	This variable aggregates the total consecutive travel distances if items were considered in a particular order. It serves as a baseline for estimating how much travel might be needed if all items were covered by a continuous path.

- ub ($ub$)  <br>
	$$ub = \lceil \frac{consec}{num\\_courier} \rceil + lb$$  <br>
	The upper bound sets a limit on the maximum allowed route length for a courier. It is computed based on a division of the total consecutive distance among the number of couriers, plus the lower bound. This provides a controlled search space, ensuring that solutions with excessively long routes are not considered.

- min_round_trip ($min\\_round\\_trip$) <br>
	$$min\_round\\_trip = \min({ distance\_mat[num\_points, i] + distance\\_mat[i, num\\_points] \mid i \in items })$$  <br>
	This variable is a stricter lower bound than $lb$ for an individual trip, representing the shortest possible round trip from the depot to any item. Every courier’s route must at least meet this minimal travel cost, ensuring that a courier who takes a route is actually performing meaningful delivery work.
- Fairness Constraint on Route Length  <br>
	$$| \space\max({length\\_of\\_path[c]}) - \min({length\\_of\\_path[c]}) \space| \space \le \space \lceil \frac{max\\_pl}{2} \rceil$$  <br>
	This constraint ensures that the difference between the longest and shortest paths (in terms of number of nodes visited) assigned to couriers is not excessively large. By limiting this gap, the solution encourages a more balanced workload distribution among couriers.

- Objective Boundaries <br>
	$$max\\_route\\_found \ge lb \quad\wedge\quad max\\_route\\_found \le ub$$  <br>
	This ensures that the maximum route found by any courier remains within the predefined lower and upper bounds. As a result, the solver avoids exploring solutions that are too short to be feasible or too long to be practical.

- Travel Distance Bounds for Each Courier
	For each courier $c$: <br>
	$$traveled\\_distance[c] \ge min\\_round\\_trip$$  <br>
	$$traveled\\_distance[c] \le ub$$ <br>
	The lower bound ensures that every courier’s assigned route is at least as long as the shortest possible round trip to an item and back, preventing trivial or empty routes. The upper bound ensures no courier’s route exceeds the calculated upper bound, keeping solutions focused and within reasonable limits.

## Constraints
Constraints are what give meaning to the modeling formulation chosen. In the following we will have an in-detail explanation of the constraints we used on the forth modeling. 

- Depot Constraints  <br>
	$$\forall c \in couriers: sequence[c, 1] = num\\_points \quad\wedge\quad sequence[c, length\\_of\\_path[c]] = num\\_points$$
	Each courier’s route must start and end at the depot, identified by $num\_points$. The first position in the $sequence$ array ($sequence[c,1]$) is always the depot, and the last position used in that courier’s route ($sequence[c,length\_of\_path[c]]$) is also the depot. This ensures that all routes form proper round trips beginning and ending at the central depot.

- Capacity Constraints  <br>
	$$bin\\_packing\\_capa(courier\\_capacity, \space bin, \space item\\_size)$$
	This constraint ensures that each courier does not exceed their carrying capacity. The $bin\\_packing\\_capa$ constraint checks item sizes assigned to each courier, ensuring the sum of those sizes does not surpass $courier\\_capacity$.
	This predicate alone, chooses a value and its index from the courier capacity and assigns the index of that value to any slots in the bin by taking into account that the sum of the sizes of the chosen slots does not exceed the value of that index taken from the courier_capacity. This is how it assigns a courier to an item, by putting the courier number in the corresponding item house in the defined bin. 

- Connecting Sequence and Bin Variables 
	- If an item $city$ is not assigned to courier $c$ (i.e., $bin[city] \neq c$), then:  <br>
    $$\forall j \in {2, \dots, max\\_pl-1} : sequence[c, j] \neq city$$
	- If an item $city$ is assigned to courier $c$ (i.e., $bin[city] = c$), then:  <br>
  	$$ \exists j \in {2, \dots, max\\_pl-1} : sequence[c, j] = city $$
	These constraints link the $bin$ assignment variables with the $sequence$ routing variables. If a courier does not carry a particular item, that item cannot appear in their route sequence. Conversely, if a courier is responsible for an item, that item must appear exactly once in their route (somewhere between the start and end depot visits).

- Defining the Length of Path  <br>
	$$\forall c \in couriers: length\_of\_path[c] = \sum_{i \in items} (bool2int(bin[i] = c)) + 2$$
	The route length for each courier is defined as the number of items assigned to them plus two for the start and end depot nodes. This ensures each courier’s path length accurately reflects the number of items they must deliver and the mandatory depot visits.

- Beyond Path Length Must Be Zero  <br>
	$$\forall c \in couriers,\ \forall i \in {length\\_of\_path[c]+1,\dots,max\\_pl} : sequence[c, i] = 0$$  <br>
	Any positions in the $sequence$ array beyond a courier’s determined path length are set to zero. This enforces that no “extra” travel nodes are used, ensuring the model does not consider unnecessary or unused slots in the route representation.

- Global Constraints 
	- All-Different Constraint for Each Courier’s Route  <br>
  		$$\forall c \in couriers: alldifferent({sequence[c, city] \mid city \in {1,\dots,length\\_of\\_path[c]-1}})$$  <br>
		Except for the depot, each visited node/item must be unique in a single courier’s route. This prevents visiting the same item multiple times and ensures a proper path structure.
	
	- Ensuring All Visited Cities for Different Couriers are Different  <br>
		$$\forall c \in couriers: alldifferent({sequence[c, city] \mid city \in {2,\dots,\min({length\\_of\\_path[k] \mid k \in couriers})-1}})$$  <br>
		Across the set of couriers, all items must collectively form a set of unique visits. This constraint somehow ensures full item coverage without duplication.

- Distance Calculation Constraints  <br>
  	$$\forall c \in couriers: traveled\\_distance[c] =$$  <br>
	$$\sum_{i=1}^{length\\_of\\_path[c]-1} distance\\_mat[sequence[c, i], sequence[c, i+1]]$$  <br>
	The total distance traveled by each courier is calculated based on the $sequence$ of nodes visited. By summing up the distances between consecutive nodes (including the depot at start and end), we obtain the actual travel cost for that route.

- Symmetry Breaking  <br>
	$$\forall (c,k) \in couriers,\ c<k,\ courier\_capacity[c] = courier\_capacity[k]: $$  <br>
	$$\quad lex\_lesseq([sequence[c,p] \mid p \in {1,\dots,max\_pl}], [sequence[k,p] \mid p \in {1,\dots,max\_pl}])$$  <br>
	Symmetry breaking constraints reduce the number of equivalent solutions the solver must consider. When two couriers have the same capacity, this lexicographical ordering ensures that one courier’s route is always considered “first” or “smaller” in some consistent manner, helping the solver converge faster.



<br><br>



## Search and Strategies
The solver attempts to minimize the maximum route length ($max\_route\_found$) across all couriers. To achieve this, the solve directive uses a structured search approach, dividing the problem into stages that focus on different sets of decision variables and then employing a combination of variable and value selection strategies to guide the search.

### Sequence Construction Phase
Here's the chosen strategy for the sequence variable. 

```c 
int_search(
			[sequence[c, i] | c in couriers, i in 1..max_pl],
			dom_w_deg,
			indomain_random,
			complete
		),
```

This step focuses on the $sequence$ variables, which define the actual visiting order of nodes (items and depot) for each courier. The strategy used here is:
- `Which variable to search for correct assignment?` `Sequence` Variable. 
- `How to select the variable inside the array of variable?` `dom_w_deg` (Choose the variable with largest domain, divided by the number of attached constraints weighted by how often they have caused failure), which prioritizes variables that appear in the largest number of constraints or have the most constrained domains. This can help in quickly identifying critical route assignments.
- `How to select a value for that variable?`: `indomain_random`, which chooses values randomly within the allowed domain. Random selection diversifies the search, helping the solver escape local minima or heavily constrained areas.
- `What is the search strategy?` `complete`, which is an exhaustive exploration of the search space.


### Item Assignment Optimization
As the second choice for solving, we choose the Item Assignment variable, the `Bin` variable. 

```c
int_search(         
			[bin[i] | i in items],
			first_fail,
			indomain_random,
			complete
		),
```

Once the structure of possible routes is in place, the search moves on to deciding how items are assigned to couriers. The $bin$ variables indicate which courier delivers each item.
- `Variable Selection`: $first\_fail$, which selects the variable with the smallest domain first. 
- `Value Selection`: $indomain\_random$, again ensuring that the solver tries various assignments, improving the chances of finding high-quality solutions.
- `Strategy`: $complete$.


### Courier Route Length Optimization

```c
int_search(
			length_of_path,
			first_fail,
			indomain_median,
			complete
		)
```

The final phase involves refining the $length\_of\_path$ variables, which determine how long each courier’s route will be.
- `Variable Selection`: again focusing on the most constrained variables first.

- `Value Selection`: a heuristic that picks a “middle” value from the domain. 

- `Strategy`: $complete$.
	Additionally, we have also tried using some other interesting annotation that changes the way solver interacts with the variables and the solution it finds.

- Relax and Reconstruc <br>
	$$:: relax\_and\_reconstruct(array1d(sequence), 80)$$
	 <br>
	Simple large neighborhood search strategy: This annotation says that upon restart, for each variable in sequence , the probability of it being fixed to the previous solution is 80 percent.

- Restart Polic <br>
	$$:: restart\_linear(num\_item)$$ 
	<br>
	Restart with linear sequence scaled by `num_item`. Alternatively you could use, `restart_constant(scale)` for restarting after constant number of nodes each time `scale`, `restart_luby(scale)` for restarting with Luby sequence scaled by scale.

	<br>

	Restart search is much more robust in finding solutions, since it can avoid getting stuck in a non-productive area of the search. Note that restart search does not make much sense if the underlying search strategy does not do something different the next time it starts at the top. The simplest way to ensure that something is different in each restart is to use some randomization, either in variable choice or value choice. Alternatively some variable selection strategies make use of information gathered from earlier search and hence will give different behaviour, for example dom_w_deg.

- Objective <br>
	$$minimize\ max\_route\_found$$  
	<br>
	By applying these layered search strategies (layered with help of (`seq_search` which takes these integer search in input and applies them sequentially) — focusing first on route structure (`sequence`), then on item assignment (`bin`), and finally on route length (`length_of_path`)—and combining them with relaxation, reconstruction, and periodic restarts, the solver aims to efficiently explore the solution space. 

<br><br>

## Experiment and Experience
Empirically, we understood that at the end, what matters most in achieving better results and optimal or near-optimal solutions is applying good modeling to the problem. Real-world problems, which are usually as large as the given-above-ten instances, themselves have lots of values and possibilities. Hence, it is important to implement the modeling part in a way that does not increase these variations and makes the solution more clear, easier, and accessible to the solver. In this problem, although we have tried three different ways of modeling, each of which was better than the other, at the end, the only thing that helped us the most was the heuristic approach we chose. Considering a relaxed and fair distribution of items led us toward choosing a smaller dimension in the 4th modeling, leading to significantly fewer variables for the solver. 
Precisely speaking, with help of `Gecode Gist`, which is a solver configuration that demonstrates the search tree and especially they number of variables, we figured out that in the first modeling for the path matrix, the solver was dealing with `414720` boolean variables, which, mathematically, equals to ${num\_point} \space *  \space {num\_point} \space *  \space {num\_courier}$. This value equals to `20736` variables of domain '0..20', which in terms of variables was a significant improvement. Although one might say considering the number of values in the domain makes the equation the same, in practice, since we are applying constraint constraints to the domain of the variables, usually the available values in the domain is less than what math suggests. Math is only suggesting the values before applying any constraints. However, we cannot omit or not consider the variables, and solvers always have to find a value for them from their domain. Each variable equals to one decision. 
The result improved even more on the 3rd modeling, and we had only `2880` variables of domain `1..144`. Respectively, we were seeing and experiencing the resultt of this change in parameters based on the solutions we were getting on this and other hard instances. 
But the game changer was the 4th modeling. In which, by applying heuristic, we achieved `200` variables with the domain of `0..144` values on INSTANCE11!

This experimental study helped us understand how modeling can affect the solver and the exploration it might help. More importantly, we learnt that a good heuristic and relaxation, at the end, are what will save you on the real large-size data. 



## Table of results
The following list, is the table of output based on the models. Here's a briefly explanation of the models that you may find useful when running the models. Having 4 different modelings and 3 different variants based on the solvers:
- Modeling 1
	- When running this model you must not expect it running on instances above 10 successfully. This model is not suggested, however if you want to test it, it is best suited for the first 10 instances.
- Modeling 2 
	- This modeling, which mathematically is improved significantly on the number of the variables that solver has to deal with, is a better choice on the first 10 instances. You can get results faster and get less solution. You may also be able to get some solution on instances above 10. But, yet it is not strong enough to find optimal on those instances and you may not expect to get optimal on more than one instances.
- Modeling 3
	- Even though we, once again, experienced a significant change on the number of the variables, still the optimal results that we could get for instances above ten didn't change much, and we were just experiencing faster solution finding, and also one more optimality.
- Model 4
	- This model achieved breakthrough results, delivering more optimal outcomes in some cases, even achieving optimal results for instances exceeding 10 in a matter of mili seconds.This is our suggested model. Hence, one downside to this model is that, it doesn't terminated on the small instance like instance 1 and instance 5 although it finds the optimality in ms. 

- `*` indicates that a solution is found (Not Optimal) and program terminated
- `**` indicates that the optimal solution is found and program terminated successfully
- `NSol` No solution found
- `Results` column gives the maximum value of the set of distances that each courier traveled

<br><br>

| Instance |  3D Path Approach GECODE |  3D Path Approach CHUFFED |  3D Path Approach ORTOOLS |  2D Path Approach GECODE |  2D Path Approach CHUFFED |  2D Path Approach ORTOOLS |  2D Sequence Base Approach GECODE |  2D Sequence Base Approach CHUFFED |  2D Sequence Base Approach ORTOOLS |  2D Heuristic Sequence Approach ORTOOLS |  2D Heuristic Sequence Approach CHUFFED |  2D Heuristic Sequence Approach GECODE |  2D Heuristic Sequence Approach ORTOOLS CP |  2D Heuristic Sequence Approach GECODE WITHOUT SYM |  2D Heuristic Sequence Approach GECODE WITHOUT RAR |
|----------|----------|----------|----------|----------|----------|----------|----------|----------|----------|----------|----------|----------|----------|----------|----------|
| 1 | 14 `**` | 14 `**` | 14 `**` | 14 `**` | 14 `**` | 14 `**` | 14 `*` | 14 `**` | 14 `**` | 14 `**` | 14 `**` | 14 `*` | 14 `**` | 14 `*` | 14 `**` |
| 2 | 226 `**` | 226 `**` | 226 `**` | 226 `**` | 226 `**` | 226 `**` | 226 `**` | 226 `**` | 226 `**` | 226 `**` | 226 `**` | 226 `**` | 226 `**` | 226 `**` | 226 `**` |
| 3 | 12 `**` | 12 `**` | 12 `**` | 12 `**` | 12 `**` | 12 `**` | 12 `*` | 12 `**` | 12 `**` | 12 `**` | 12 `**` | 12 `*` | 12 `**` | 12 `*` | 12 `**` |
| 4 | 220 `**` | 220 `**` | 220 `**` | 220 `**` | 220 `**` | 220 `**` | 220 `**` | 220 `**` | 220 `**` | 220 `**` | 220 `**` | 220 `**` | 220 `**` | 220 `**` | 220 `**` |
| 5 | 206 `**` | 206 `**` | 206 `**` | 206 `**` | 206 `**` | 206 `**` | 206 `**` | 206 `**` | 206 `**` | 206 `**` | 206 `**` | 206 `*` | 206 `**` | 206 `*` | 206 `**` |
| 6 | 322 `**` | 322 `**` | 322 `**` | 322 `**` | 322 `**` | 322 `**` | 322 `**` | 322 `**` | 322 `**` | 322 `**` | 322 `**` | 322 `**` | 322 `**` | 322 `**` | 322 `**` |
| 7 | 167 `**` | 167 `**` | 187 `*` | 167 `**` | 167 `**` | 172 `*` | 167 `**` | 167 `**` | 167 `**` | 167 `**` | 167 `**` | 167 `**` | 167 `**` | 167 `**` | 167 `**` |
| 8 | 186 `**` | 186 `**` | 186 `**` | 186 `**` | 186 `**` | 186 `**` | 186 `**` | 186 `**` | 186 `**` | 186 `**` | 186 `**` | 186 `**` | 186 `**` | 186 `**` | 186 `**` |
| 9 | N/A `*` | 436 `**` | 436 `**` | 436 `**` | 436 `**` | 436 `**` | 436 `**` | 436 `**` | 436 `**` | 436 `**` | 436 `**` | 436 `**` | 436 `**` | 436 `**` | 436 `**` |
| 10 | N/A `*` | 244 `**` | 244 `**` | 244 `**` | 244 `**` | 244 `**` | 244 `**` | 244 `**` | 244 `**` | 244 `**` | 244 `**` | 244 `**` | 244 `**` | 244 `**` | 244 `**` |
| 11 | N/A `*` | N/A `*` | N/A `*` | 926 `*` | N/A `*` | N/A `*` | 505 `*` | N/A `*` | 918 `*` | 773 `*` | N/A `*` | 305 `*` | N/A `*` | 305 `*` | 698 `*` |
| 12 | N/A `*` | N/A `*` | N/A `*` | N/A `*` | N/A `*` | N/A `*` | 346 `**` | N/A `*` | 662 `*` | 495 `*` | 610 `*` | 346 `**` | 610 `*` | 346 `**` | 370 `*` |
| 13 | N/A `*` | N/A `*` | 838 `*` | 1148 `*` | N/A `*` | 1420 `*` | 452 `*` | 1500 `*` | 1388 `*` | 1054 `*` | 1236 `*` | 454 `*` | 1236 `*` | 442 `*` | 1036 `*` |
| 14 | N/A `*` | N/A `*` | N/A `*` | N/A `*` | N/A `*` | N/A `*` | 762 `*` | N/A `*` | N/A `*` | N/A `*` | N/A `*` | 491 `*` | N/A `*` | 461 `*` | 1096 `*` |
| 15 | N/A `*` | N/A `*` | N/A `*` | N/A `*` | N/A `*` | N/A `*` | 818 `*` | N/A `*` | N/A `*` | N/A `*` | N/A `*` | 581 `*` | N/A `*` | N/A `*` | 1088 `*` |
| 16 | 785 `*` | N/A `*` | N/A `*` | 382 `*` | N/A `*` | N/A `*` | 286 `**` | 325 `*` | 375 `*` | 286 `**` | 286 `**` | 286 `**` | 286 `**` | 286 `**` | 286 `**` |
| 17 | N/A `*` | N/A `*` | N/A `*` | N/A `*` | N/A `*` | N/A `*` | 1518 `*` | N/A `*` | N/A `*` | N/A `*` | N/A `*` | N/A `*` | N/A `*` | 1221 `*` | N/A `*` |
| 18 | N/A `*` | N/A `*` | N/A `*` | N/A `*` | N/A `*` | N/A `*` | 647 `*` | N/A `*` | N/A `*` | 959 `*` | N/A `*` | 389 `*` | N/A `*` | 360 `*` | 887 `*` |
| 19 | N/A `*` | N/A `*` | N/A `*` | 595 `*` | N/A `*` | N/A `*` | 334 `**` | N/A `*` | 597 `*` | 334 `**` | 450 `*` | 334 `**` | 450 `*` | 334 `**` | 334 `**` |
| 20 | N/A `*` | N/A `*` | N/A `*` | N/A `*` | N/A `*` | N/A `*` | N/A `*` | N/A `*` | N/A `*` | N/A `*` | N/A `*` | N/A `*` | N/A `*` | N/A `*` | N/A `*` |
| 21 | N/A `*` | N/A `*` | N/A `*` | N/A `*` | N/A `*` | N/A `*` | 525 `*` | N/A `*` | 1070 `*` | 854 `*` | N/A `*` | 374 `**` | N/A `*` | 374 `**` | 756 `*` |
