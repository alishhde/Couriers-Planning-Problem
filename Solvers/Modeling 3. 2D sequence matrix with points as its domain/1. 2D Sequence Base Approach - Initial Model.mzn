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

% Sequence Variable ; Main decision variable
array[couriers, points] of var points: sequence;

% Bin variable for item assignment controling
array[items] of var couriers: bin;

% For lexicoographic ordering
array[couriers] of int: sorted_couriers = arg_sort(courier_capacity); 



% =-=-=-=-=-=-=-=- Constraints -=-=-=-=-=-=-=-=
% All cities must be visited and visited once
constraint
  forall(i in items)(
    sum([bool2int(sequence[c, i] != i) | c in couriers]) = 1
  );

% Ensuring each courier starts/ends at a depot
constraint
  forall(c in couriers)(
        sequence[c, num_points] != num_points
     /\ exists(i in points)(sequence[c, num_points] = i)
     /\ exists(i in items)(sequence[c, i] = num_points)
  );

% Apply subcircuit constraint for each courier
constraint
  forall(c in couriers)(
    subcircuit([sequence[c, i] | i in points])
  );

% Link bin to sequence
constraint
  forall(j in items)(
    forall(c in couriers)(
      exists(i in points where i != j)(sequence[c, i] = j)  <- bin[j] = c
    )
  );

% Apply bin_packing_capa constraint
constraint
  bin_packing_capa(courier_capacity, bin, item_size);
  
% Distance calculation
constraint
  forall(c in couriers)(
    traveled_distance[c] = sum([
      distance_mat[i, sequence[c, i]] * (sequence[c, i] != i)
      | i in points
    ])
  );

% Ensure each courier's sequence visits unique points
constraint
  forall(c in couriers)(
    alldifferent([sequence[c, i] | i in points])
  );



% =-=-=-=-=-=-=-=- Objective and Boundaries -=-=-=-=-=-=-=-=
% Objective var
var int: max_rout_found = max([traveled_distance[c] | c in couriers]);

% Minimum possible distance that a courier should go; going from a depot to an item
var int: lb; 
lb = max([distance_mat[num_points, i] + distance_mat[i, num_points] | i in items]);

% Maximum possible distqnace that a courier may go
var int: consec; consec = sum([distance_mat[i, i+1] | i in 1..num_item-1]);
var int: ub; ub = ceil(consec / num_courier) + lb;

% Limiting boundaries for objective function
constraint max_rout_found >= lb
        /\ max_rout_found <= ub;

var int: min_round_trip;
min_round_trip = min([distance_mat[num_points, i] + distance_mat[i, num_points] | i in items]);

% Bounding the minimum and maximum possible travel
constraint forall(c in couriers)(traveled_distance[c] >= min_round_trip);
constraint forall(c in couriers)(traveled_distance[c] <= ub);

% Solve statement with Luby restart strategy
solve
  :: int_search(
      [sequence[c, i] | c in couriers, i in points],
      dom_w_deg,
      indomain_random,
      complete
    )
  :: restart_luby(100)
  minimize max_rout_found;