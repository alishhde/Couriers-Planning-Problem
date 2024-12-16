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
% Matrix of size num_points * num_points with domain of couriers
array[points, points] of var couriers union {0}: path; % 0 indicates no path

% Array of size num_courier; For keeping the traveled distance
array[couriers] of var int: traveled_distance;

% Sequence Variable for Subcircuit
array[couriers, points] of var points: sequence;



% =-=-=-=-=-=-=-=- Constraints -=-=-=-=-=-=-=-=
% All cities must be visited and visited once
constraint
  forall(it in items)(
       sum([path[it, column] != 0  | column in points])  = 1   % Outgoing arcs
    /\ sum([path[row,    it] != 0  | row    in points])  = 1   % Incoming arcs
  );

% Ensuring each courier starts/ends at a depot
constraint
  forall(c in couriers)(
       among(1, [path[row, num_points] | row in items], {c})  % Courier c ends at depot
    /\ among(1, [path[num_points, col] | col in items], {c})  % Courier c starts from depot
  );

% Apply subcircuit constraint for each courier
constraint
  forall(c in couriers)(
    subcircuit([sequence[c, i] | i in points])
  );

% Constraint on capacities of couriers; must not exceed
constraint 
  bin_packing_capa(
    courier_capacity,  % capacity per courier|bins
    [sum([path[j, i] | j in points]) | i in items], item_size
);

% No self-loops
constraint
  forall(diag in points)(
    path[diag, diag] = 0
  );

% Distance calculation
constraint
  forall(c in couriers)(
    traveled_distance[c] = sum([if path[row, col] = c then distance_mat[row, col] else 0 endif | row, col in points])
  );

% Ensure each courier's sequence visits unique points
constraint
  forall(c in couriers)(
    alldifferent([sequence[c, i] | i in points])
  );
  
%  channeling constraint
constraint
  forall(c in couriers, i, j in points where i != j)(
    (path[i, j] = c) <-> (sequence[c, i] = j)
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
      [path[i, j] | i, j in points],
      input_order,
      indomain_max,
      complete
    )
  :: relax_and_reconstruct(array1d(path), 80)
  :: restart_luby(100)
  minimize max_rout_found;