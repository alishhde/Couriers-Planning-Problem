include "globals.mzn";

% =-=-=-=-=-=-=-=- Parameters -=-=-=-=-=-=-=-=
% Number of Courier
int: num_courier;
set of int: couriers = 1..num_courier;
array[couriers] of int: courier_capacity;

% Number of Items
int: num_item;
set of int: items = 1..num_item;
array[items] of int: item_size;

% Number of distribituion points
int: num_points = num_item + 1;
set of int: points = 1..num_points;

% Distance Matrix
array[points, points] of int: distance_mat;


% =-=-=-=-=-=-=-=- Decision Variables -=-=-=-=-=-=-=-=
% Matrix of size num_points * num_points * num_courier
array[points, points, couriers] of var 0..1: path;

% Array of size num_courier; For keeping the traveled distance
array[couriers] of var int: traveled_distance;

% MTZ variables; Subtour elimination variables
array[couriers, points] of var int: u;

% =-=-=-=-=-=-=-=- Constraints -=-=-=-=-=-=-=-=
% All couriers must end in depot
constraint
  forall(c in couriers)(
     sum([path[row, num_points, c] | row in items]) = 1 
  );

% All courier must start from depot
constraint
  forall(c in couriers)(  
    sum([path[num_points, column, c] | column in items]) = 1
  );

% All cities must be visited and visited once 
%% Row Base Constraint; There exists one Outgoing arc from each point
constraint 
  forall(row in items)(
    sum([path[row, column, c] | c in couriers, column in points]) = 1 
  );
  
%% Column Base Constraint; There exists one Incoming arc to each point
constraint 
  forall(column in items)(
    sum([path[row, column, c] |  c in couriers, row in points]) = 1
  );

% Flow conservation for each courier and each customer;
constraint                   
  forall(c in couriers) (
    forall(i in items)(
      sum([path[j, i, c] | j in points where j != i]) =
      sum([path[i, j, c] | j in points where j != i])
    )
  );
  
% Subtour elimination constraints
constraint forall(c in couriers)(
  forall(i in points)(
        u[c, i] >= 0 
    /\  u[c, i] <= num_item 
  ) /\
  
  forall(j in items)(
    forall(k in items where j != k)(
      path[j, k, c] = 1 -> u[c, k] = u[c, j] + 1
    )  
  )
);

% Constraint on capacities of couriers; must not exceed
constraint 
  forall(c in couriers)(
    sum([item_size[i] * sum([path[i, j, c] | j in points]) | i in items])
    <= courier_capacity[c]
  );
  

% NO Self Loop; Diagnol should be zero
constraint 
  forall(c in couriers, diag in points)(
    path[diag, diag, c] = 0
  );
  

% Distance Calculation
constraint
  forall(c in couriers)(
    traveled_distance[c] = sum([path[row, col, c] * distance_mat[row, col] | row, col in points])
  );

  
% =-=-=-=-=-=-=-=- Objective and Boundaries -=-=-=-=-=-=-=-=
% Objective var
var int: max_rout_found = max([traveled_distance[c] | c in couriers]);


% Minimum possible distance that a courier should go; going from a depot to an item
var int: minimum_travel_dist; 
constraint minimum_travel_dist = max([distance_mat[num_points, i] + distance_mat[i, num_points] | i in items]);

% Maximum possible distqnace that a courier may go
var int: one_feasible_possible_travel_dist;
constraint one_feasible_possible_travel_dist = sum([distance_mat[i, i+1] | i in items]) + max([distance_mat[num_points, i] | i in items]);

% Limiting boundaries for objective function
constraint max_rout_found >= minimum_travel_dist
        /\ max_rout_found <= one_feasible_possible_travel_dist;

var int: min_round_trip;
constraint min_round_trip = min([distance_mat[num_points, i] + distance_mat[i, num_points] | i in items]);

constraint forall(c in couriers)(traveled_distance[c] >= min_round_trip);
constraint forall(c in couriers)(traveled_distance[c] <= one_feasible_possible_travel_dist);


solve
  :: int_search(
      [path[i, j, c] | c in couriers, i, j in points],
      first_fail,
      indomain_min,
      complete)
  minimize max_rout_found;