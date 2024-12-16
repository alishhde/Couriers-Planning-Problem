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

% Subcircuit variables; Subtour elimination variables
array[couriers, points] of var int: sequence;


% =-=-=-=-=-=-=-=- Constraints -=-=-=-=-=-=-=-=
% All cities must be visited and visited once 
constraint 
  forall(it in items)(
       sum([path[it, column, c] | c in couriers, column in points]) = 1   % Outgoing arcs from each city
    /\ sum([path[row, it, c]    | c in couriers, row    in points]) = 1   % Incoming arcs to each city
  );
  

% All couriers must end in depot
constraint
  forall(c in couriers)(
         sum([path[row,    num_points, c] | row    in items]) = 1  
    /\   sum([path[num_points, column, c] | column in items]) = 1 
  );


% Flow conservation for each courier and each customer;
constraint                   
  forall(c in couriers) (
    forall(i in items)(
      sum([path[j, i, c] | j in points where j != i]) =
      sum([path[i, j, c] | j in points where j != i])
    )
  );


% Link sequence and path variables
constraint
  forall(c in couriers)(
    forall(i in points)(
      sequence[c, i] = sum([path[i, j, c] * j | j in points]) + 
                       i * (1 - sum([path[i, j, c] | j in points]))
    )
  );
  

% Apply subcircuit constraint
constraint
  forall(c in couriers)(
    subcircuit([sequence[c, i] | i in points])
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
  

% % Break symmetries between couriers with equal capacities; The below one works better
% constraint
%   forall(c1, c2 in couriers where c1 < c2 /\ courier_capacity[c1] = courier_capacity[c2])(
%     lex_lesseq([traveled_distance[c] | c in couriers], [traveled_distance[c] | c in couriers])
%   );
  
% Lexicographical; Helps significantly
array[1..num_courier] of int: sorted_indices = arg_sort(courier_capacity);

constraint
    forall(k in 1..num_courier-1) (
        let { 
            int: current_courier = sorted_indices[k];
            int: next_courier = sorted_indices[k+1];
            % Flatten the route matrix for each courier into a list
            array[1..num_item * num_item] of var int: current_route = 
                [path[i, j, current_courier] | i in 1..num_item, j in 1..num_item];
            array[1..num_item * num_item] of var int: next_route = 
                [path[i, j, next_courier] | i in 1..num_item, j in 1..num_item];
        } in
        % Apply lexicographic ordering constraint only if the capacities are the same
        if courier_capacity[current_courier] = courier_capacity[next_courier] then
            lex_lesseq(current_route, next_route)
        else
            true
        endif
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
  :: restart_luby(100)
  minimize max_rout_found;