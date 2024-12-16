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
% Array of size num_courier; For keeping the traveled distance
array[couriers] of var int: traveled_distance;

% Bin variable for item assignment controling
array[items] of var couriers: bin;

% Defining Arbitrary num of the columns; to decrease the dimension more
int: max_pl = ceil(num_item / num_courier) + 2;
set of int: num_nodes = 1..max_pl;

% Sequence Variable ; Main decision variable
array[couriers, num_nodes] of var 0..num_points: sequence;

% Defing a variable for keeping the length of the path
array[couriers] of var 3..max_pl: length_of_path;



% =-=-=-=-=-=-=-=- Constraints -=-=-=-=-=-=-=-=
%% CONSTRAINTS ON SEQUENCE MATRIX
% PATH STARTS AND ENDS IN DEPOT
constraint 
  forall(c in couriers)(
        sequence[c, 1] = num_points
    /\  sequence[c, length_of_path[c]] = num_points
  );

% Connecting SEQUENCE AND BINS
constraint 
  forall(c in couriers, city in items)(
        (if bin[city] != c then forall(j in 2..max_pl-1)(sequence[c, j] != city) endif)
    /\  (if bin[city]  = c then exists(j in 2..max_pl-1)(sequence[c, j]  = city) endif)
  );
  
% BEYOND PATH LENGTH MUST BE ZERO
constraint
  forall(c in couriers, i in length_of_path[c]+1..max_pl)(
      sequence[c, i] = 0
  );
  
% DEFINING THE LENGTH OF PATH
constraint 
  forall(c in couriers)(
        length_of_path[c] = sum([bool2int(bin[i] = c) | i in items]) + 2
  );
  
%% CONSTRAINTS ON CAPACITY and BIN
% Apply bin_packing_capa constraint
constraint
  bin_packing_capa(courier_capacity, bin, item_size);

%% Adding Global Constraints
% Visiting cities must be different
constraint 
  forall(c in couriers)(
    alldifferent([sequence[c, city] | city in 1..length_of_path[c]-1]) % DEPOTS ARE ALREADY SET
  );

% Cities must be visited once
constraint 
  forall(c in couriers)(
    alldifferent([sequence[c, city] | city in 2..min([length_of_path[k] | k in couriers])-1]) % DEPOTS ARE ALREADY SET
  );

% DISTANCE CALCULATIONS
constraint
  forall(c in couriers)(
    traveled_distance[c] = sum([
      distance_mat[sequence[c, i], sequence[c, i+1]] 
      | i in 1..length_of_path[c]-1
    ])
  );



% =-=-=-=-=-=-=-=- Objective and Boundaries -=-=-=-=-=-=-=-=
var int: max_route_found = max([traveled_distance[c] | c in couriers]);

% Minimum possible distance that a courier should go; going from a depot to an item
var int: lb;
lb = max([distance_mat[num_points, i] + distance_mat[i, num_points] | i in items]);

% Maximum possible distanace that a courier may go
var int: consec; consec = sum([distance_mat[i, i+1] | i in 1..num_item-1]);
var int: ub; ub = ceil(consec / num_courier) + lb;

% Limiting boundaries for objective function
constraint max_route_found >= lb
        /\ max_route_found <= ub;

var int: min_round_trip;
min_round_trip = min([distance_mat[num_points, i] + distance_mat[i, num_points] | i in items]);

% Bounding the minimum and maximum possible travel
constraint forall(c in couriers)(traveled_distance[c] >= min_round_trip);
constraint forall(c in couriers)(traveled_distance[c] <= ub);

solve
  :: int_search(
      [sequence[c, i] | c in couriers, i in 1..max_pl],
      dom_w_deg,
      indomain_random,
      complete
    )
  :: restart_luby(100)
  minimize max_route_found;