include "globals.mzn";


% =-=-=-=-=-=-=-=- Parameters -=-=-=-=-=-=-=-=
int: num_courier;
set of int: couriers = 1..num_courier;
array[couriers] of int: courier_capacity;

int: num_item;
set of int: items = 1..num_item;
array[items] of int: item_size;

int: num_points = num_item + 1;
set of int: points = 1..num_points;

array[points, points] of int: distance_mat;



% =-=-=-=-=-=-=-=- Decision Variables -=-=-=-=-=-=-=-=
array[couriers] of var int: traveled_distance;
array[items] of var couriers: bin;

% Defining Arbitrary num of the columns; to decrease the dimention more
int: max_pl = ceil(num_item / num_courier) + 2; % Including 2 points for depot
set of int: num_nodes = 1..max_pl; % number of nodes; heu way choosing
array[couriers, num_nodes] of var 0..num_points: sequence;

% Defing a variable for keeping the length of the path
array[couriers] of var 3..max_pl: length_of_path; % At least one item each courier should have



% =-=-=-=-=-=-=-=- Constraints -=-=-=-=-=-=-=-=
%%% CONSTRAINTS ON SEQUENCE MATRIX
%% PATH STARTS AND ENDS IN DEPOT
constraint 
  forall(c in couriers)(
        sequence[c, 1] = num_points
    /\  sequence[c, length_of_path[c]] = num_points
  );

%% Connecting SEQUENCE AND BINS
constraint 
  forall(c in couriers, city in items)(
        (if bin[city] != c then forall(j in 2..max_pl-1)(sequence[c, j] != city) endif)
    /\  (if bin[city]  = c then exists(j in 2..max_pl-1)(sequence[c, j]  = city) endif)
  );
  
%% BEYOND PATH LENGTH MUST BE ZERO
constraint
  forall(c in couriers, i in length_of_path[c]+1..max_pl)(
      sequence[c, i] = 0
  );
  
%% DEFINING THE LENGTH OF PATH
constraint 
  forall(c in couriers)(
        length_of_path[c] = sum([bool2int(bin[i] = c) | i in items]) + 2
  );
  
%%% CONSTRAINTS ON CAPACITY
%% Apply bin_packing_capa constraint
constraint
  bin_packing_capa(courier_capacity, bin, item_size);

%%% Adding Global Constraints
%% Visiting cities must be different
constraint 
  forall(c in couriers)(
    alldifferent([sequence[c, city] | city in 1..length_of_path[c]-1]) % DEPOTS ARE ALREADY SET
  );

%% Cities must be visited once
constraint 
  forall(c in couriers)(
    alldifferent([sequence[c, city] | city in 2..min([length_of_path[k] | k in couriers])-1]) % DEPOTS ARE ALREADY SET
  );
  
%%% DISTANCE CALCULATIONS
%% DISTANCE OF EACH COURIER
constraint
  forall(c in couriers)(
    traveled_distance[c] = sum([
      distance_mat[sequence[c, i], sequence[c, i+1]] 
      | i in 1..length_of_path[c]-1
    ])
  );

%%% SYMMETRY BREAKING ; NEW ON THIS VERSION ; Faster Results on INST12 ; Results 359 -> 358
constraint 
  forall(c, k in couriers where c < k /\ (courier_capacity[c] = courier_capacity[k]))( 
         lex_lesseq([sequence[c, p] | p in 1..max_pl], [sequence[k, p] | p in 1..max_pl])
  ); 
  
  

% =-=-=-=-=-=-=-=- Objective and Boundaries -=-=-=-=-=-=-=-=
var int: max_route_found = max([traveled_distance[c] | c in couriers]);

% Minimum possible distance that a courier should go; going from a depot to an item
var int: lb;
lb = max([distance_mat[num_points, i] + distance_mat[i, num_points] | i in items]);

% Maximum possible distanace that a courier may go
var int: consec; consec = sum([distance_mat[i, i+1] | i in 1..num_item-1]);
var int: ub; ub = ceil(consec / num_courier) + lb;


constraint abs(max([length_of_path[c] | c in couriers]) 
               - min([length_of_path[c] | c in couriers])) 
               <= ceil(max_pl / 2);  % NEW ON THIS VERSION ; Faster Results on INST19 ; -2sec 


% Limiting boundaries for objective function
constraint max_route_found >= lb
        /\ max_route_found <= ub;

var int: min_round_trip;
min_round_trip = min([distance_mat[num_points, i] + distance_mat[i, num_points] | i in items]);

% Bounding the minimum and maximum possible travel
constraint forall(c in couriers)(traveled_distance[c] >= min_round_trip);
constraint forall(c in couriers)(traveled_distance[c] <= ub);

solve 
    :: seq_search([
            % 1: Sequence construction
            int_search(
                [sequence[c, i] | c in couriers, i in 1..max_pl],
                dom_w_deg,
                indomain_random,
                complete
                ),
                % 2: Item assignment optimization
                int_search(                   % NEW ON THIS VERSION ; Faster Results on INST12 ; Results 358 -> 355/3m -> 353/3.30m
                    [bin[i] | i in items],
                    first_fail,
                    indomain_random,
                    complete
                ),
                % 3: Courier route length optimization
                int_search(
                    length_of_path,
                    first_fail,
                    indomain_median,
                    complete
                )
            ]) 
    :: relax_and_reconstruct(array1d(sequence), 80)  % UPDATED ON THIS VERSION; Significant effect on all instances
    :: restart_luby(num_item)  % UPDATED ON THIS VERSION; minor effect on inst12 361->359
      minimize max_route_found;
