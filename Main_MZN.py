from minizinc import Instance, Model, Solver
import os
import shutil
import datetime
import time
import logging
import json
import re
import math

TIMELIMIT = 300 # Secnonds

class MiniZinc_Mangager:
    def __init__(self,
                solver='gecode',
                solver_name=None,
                instanse_path="Instances/Instances dzn Format/", 
                model_path="Solvers/projectmodels"):
        """
        :param solver: the solver to be used; default is gecode
        :param isntanse_path: the path to the instances parent directory
        :param model_path: the path to the models parent directory
        """
        self.solver = solver
        self.solver_name = solver_name

        self.data_parent_directory = instanse_path
        self.list_of_paths_of_dzn = sorted([f for f in os.listdir(self.data_parent_directory) if not f.startswith('.')])
        
        self.model_parent_directory = model_path
        self.list_of_paths_of_models = sorted([f for f in os.listdir(self.model_parent_directory) if not f.startswith('.')])
        # Create a mapping from input numbers to model paths
        self.model_mapping = {f"{i+1:02}": model for i, model in enumerate(self.list_of_paths_of_models)}

    def get_model_path(self, input_number):
        """
        Get the model path corresponding to the input number.
        :param input_number: the input number as a string
        :return: the model path
        """
        return self.model_mapping.get(input_number)

    def create_model(self, path_to_model=None, data_instance_num: int=0):
        """
        :param path_to_model: path to the model file
        :param data_instance: string of data; all the parameters define in that string with mzn rules
        :return: the model instance for the provided data
        """
        self.selected_model_path = path_to_model
        path_to_model = os.path.join(self.model_parent_directory, self.selected_model_path)
        print(path_to_model)
        self.model_instance = Model(path_to_model)
        
        path_to_dzn = os.path.join(self.data_parent_directory, self.list_of_paths_of_dzn[data_instance_num-1])
        with open(path_to_dzn, 'r') as file:
            dzn_file = file.read().replace('\n', '')

        # Extract the number of couriers from the data
        courier_string = dzn_file.split(";")[0]
        match = re.search(r'\d+', courier_string)
        self.couriers = None
        if match:
            self.couriers = int(match.group())

        self.model_instance.add_string(dzn_file)

        return self.model_instance

    def solve_instance(self, model_instance=None):
        """
        :param model_instance: the created model with its data
        :param solver: choice of solver; default is gecode
        :return: the result of the solver
        """
        self.chosen_solver = self.solver
        if model_instance == None:
            self.solver = Solver.lookup(self.chosen_solver)
            self.instance = Instance(self.solver, self.model_instance)
            self.result = self.instance.solve(
                                            timeout=datetime.timedelta(seconds=TIMELIMIT)) # , intermediate_solutions=True
        else:
            self.solver = Solver.lookup(self.chosen_solver)
            self.instance = Instance(self.solver, model_instance)
            self.result = self.instance.solve(
                                            timeout=datetime.timedelta(seconds=TIMELIMIT)) # , intermediate_solutions=True
        return self.result
    
    def found_courier_path(self):
        """
        Convert the path to a list of found routes for each courier.
        """
        if self.selected_model_path[:2] in ('01', '02', '03'):
            self.solutions = self.result.solution
            solution = self.solutions
            sequences = solution.sequence
            distribution_points = len(self.result.solution.sequence[0])
            travel_route = []
            for each_courier_sequence in sequences:
                per_courier_path = [distribution_points]
                per_courier_path.append(each_courier_sequence[per_courier_path[-1]-1])
                while per_courier_path[-1] != distribution_points:
                    per_courier_path.append(each_courier_sequence[per_courier_path[-1]-1])
                travel_route.append(per_courier_path[1:-1])
            return travel_route
        elif self.selected_model_path[:2] in ('04', '05', '06'):
            self.solutions = self.result.solution
            solution = self.solutions
            paths = solution.path
            travel_route = []
            distribution_points = len(paths)
            for courier in range(1, self.couriers+1):
                per_courier_path = [distribution_points]
                per_courier_path.append(paths[distribution_points-1].index(courier)+1)
                while per_courier_path[-1] != distribution_points:
                    per_courier_path.append(paths[per_courier_path[-1]-1].index(courier)+1)
                travel_route.append(per_courier_path[1:-1])
            return travel_route
        elif self.selected_model_path[:2] in ('07', '08', '09'):
            self.solutions = self.result.solution
            solution = self.solutions
            sequences = solution.sequence
            distribution_points = len(self.result.solution.sequence[0])
            travel_route = []
            for each_courier_sequence in sequences:
                per_courier_path = [distribution_points]
                per_courier_path.append(each_courier_sequence[per_courier_path[-1]-1])
                while per_courier_path[-1] != distribution_points:
                    per_courier_path.append(each_courier_sequence[per_courier_path[-1]-1])
                travel_route.append(per_courier_path[1:-1])
            return travel_route
        elif self.selected_model_path[:2] in ('10', '11', '12', '13', '14', '15', '16'):
            travel_route = []
            for list_of_paths in self.result.solution.sequence:
                per_courier_path = []
                for point in list_of_paths:
                    if point != 0:
                        per_courier_path.append(point)
                travel_route.append(per_courier_path[1:-1])
            return travel_route
    

    def solution_to_dict(self, result=None, solution=None):
        """
        Convert a Solution object to a dictionary for JSON file.
        """
        if str(self.result.status) == 'UNSATISFIABLE' or str(self.result.status) == 'UNKNOWN':
            return {f"{self.solver_name}":
                    {
                        "time": TIMELIMIT,
                        "optimal": False,
                        "obj": "N/A",
                        "sol": []
                    }}
        elif str(self.result.status) == 'SATISFIED':
            self.solutions = self.result.solution
            solution = self.solutions
            return {f"{self.solver_name}":
                    {
                        "time": TIMELIMIT,
                        "optimal": False,
                        "obj": solution.objective,
                        "sol": self.found_courier_path() 
                    }}
        elif str(self.result.status) == 'OPTIMAL_SOLUTION':
            self.solutions = self.result.solution
            solution = self.solutions
            return {f"{self.solver_name}":
                    {
                        "time": math.floor(self.result.statistics['solveTime'].total_seconds()),
                        "optimal": True,
                        "obj": solution.objective,
                        "sol": self.found_courier_path()
                    }}

    def save_to_JSON(self, result, filename, parent_path="res/MiniZinc/", keep_prev=False):
        """
        :param result: the result of the model; either terminated before 300 or at 300
        :return: a JSON file containing the result
        """
        path_to_file = os.path.join(parent_path, f"{filename}.json")
        directory = os.path.dirname(path_to_file)
        if not os.path.exists(directory):
            os.makedirs(directory)

        if keep_prev and os.path.exists(path_to_file):
            with open(path_to_file, 'r') as json_file:
                existing_data = json.load(json_file)
            if isinstance(existing_data, dict):
                existing_data.update(result)
            else:
                existing_data = result
        else:
            existing_data = result

        with open(path_to_file, 'w') as json_file:
            json.dump(existing_data, json_file, indent=4)


    def __str__(self):
        pass


def project_result_generator(inst_range, model_path, one_instance=False):
    minizinc_manager = MiniZinc_Mangager()
    
    if one_instance:
        inst_num = inst_range
        print("\nInstance Number: ", inst_num, " for model: ", model_path)
        solver = model_path.split('-')[-1]
        solver, solver_name = get_solver_name(solver)
        model_name = model_path
        
        minizinc_manager = MiniZinc_Mangager(solver=solver, solver_name=model_name)
        model_instance = minizinc_manager.create_model(path_to_model=model_path, data_instance_num=inst_num)
        result = minizinc_manager.solve_instance(model_instance=model_instance)
        sol_dict = minizinc_manager.solution_to_dict(solution=result.solution)
        minizinc_manager.save_to_JSON(sol_dict, filename=inst_num, parent_path='Results/mzn', keep_prev=True)
    else:
        for inst_num in inst_range:
            print("Instance Number: ", inst_num, " for model: ", model_path)

            solver = model_path.split('-')[-1]
            solver, solver_name = get_solver_name(solver)
            model_name = model_path
            
            minizinc_manager = MiniZinc_Mangager(solver=solver, solver_name=model_name)
            model_instance = minizinc_manager.create_model(path_to_model=model_path, data_instance_num=inst_num)
            result = minizinc_manager.solve_instance(model_instance=model_instance)
            sol_dict = minizinc_manager.solution_to_dict(solution=result.solution)
            minizinc_manager.save_to_JSON(sol_dict, filename=inst_num, parent_path='Results/mzn', keep_prev=True)

def get_solver_name(solver):
            solver_mapping = {
                ' GECODE.mzn': ('gecode', 'gecode'),
                ' GECODE WITHOUT SYM.mzn': ('gecode', 'gecode without sym'),
                ' GECODE WITHOUT RAR.mzn': ('gecode', 'gecode without rar'),
                ' CHUFFED.mzn': ('chuffed', 'chuffed'),
                ' ORTOOLS.mzn': ('cp-sat', 'cp-sat'),
                ' ORTOOLS CP.mzn': ('cp', 'cp'),
                ' GUROBI.mzn': ('gurobi', 'Gurobi') # Gurobi is not available 
            }
            return solver_mapping.get(solver, (None, None))

def main():
    # Initialization
    minizinc_manager = MiniZinc_Mangager()

    print()
    for ind, path in enumerate(minizinc_manager.list_of_paths_of_dzn):
        print("   ", path, end="   ")
        if (ind+1) % 7 == 0:
            print()
    
    print()
    for ind, path in enumerate(minizinc_manager.list_of_paths_of_models):
        print("   ", path, end="   ")
        if (ind+1) % 2 == 0:
            print()
    
    instance_method = input("\n Now, \n Enter '1:4-01' to run the model 01 on instances 1, 2, 3, 4\n '1,3-01' for running instance 1 and 3 on model 01\n   Enter your choice: ")

    input_list = instance_method.split('-')
    model_number = input_list[1]

    if model_number.lower() == 'all':
        if input_list[0] == 'all':
            instance_number = list(range(1, 22))
            one_instance = False
        elif len(input_list[0]) <= 2:
            instance_method = '1'
            instance_number = int(input_list[0])
            one_instance = True
        elif ':' in input_list[0]:
            instance_method = '2'
            instance_number_range = list(map(int, input_list[0].split(':')))
            instance_number = range(instance_number_range[0], instance_number_range[1]+1)
            one_instance = False
        elif ',' in input_list[0]:
            instance_method = '3'
            instance_number = list(map(int, input_list[0].split(',')))
            one_instance = False

        for model_path in minizinc_manager.list_of_paths_of_models:
            project_result_generator(instance_number, model_path, one_instance=one_instance)
    else:
        model_path = minizinc_manager.get_model_path(model_number)
        solver = model_path.split('-')[-1]
        
        solver, solver_name = get_solver_name(solver)

        if input_list[0].lower() == 'all':
            instance_number = list(range(1, 22))
            instance_method = '3'
        elif len(input_list[0]) <= 2:
            instance_method = '1'
            instance_number = int(input_list[0])
        elif ':' in input_list[0]:
            instance_method = '2'
            instance_number = list(map(int, input_list[0].split(':')))
        elif ',' in input_list[0]:
            instance_method = '3'
            instance_number = list(map(int, input_list[0].split(',')))

        if instance_method == '1':
            minizinc_manager = MiniZinc_Mangager(solver=solver, solver_name=solver_name)
            print("\nSolving Instance ", instance_number)
            model_instance = minizinc_manager.create_model(path_to_model=model_path, data_instance_num=instance_number)
            result = minizinc_manager.solve_instance(model_instance=model_instance)
            sol_dict = minizinc_manager.solution_to_dict(solution=result.solution)
            minizinc_manager.save_to_JSON(sol_dict, filename=instance_number)
        elif instance_method == '2':
            for inst_num in range(instance_number[0], instance_number[1]+1):
                print("\nSolving Instance ", inst_num)
                minizinc_manager = MiniZinc_Mangager(solver=solver, solver_name=solver_name)
                model_instance = minizinc_manager.create_model(path_to_model=model_path, data_instance_num=inst_num)
                result = minizinc_manager.solve_instance(model_instance=model_instance)
                sol_dict = minizinc_manager.solution_to_dict(solution=result.solution)
                minizinc_manager.save_to_JSON(sol_dict, filename=inst_num)
        elif instance_method == '3':
            for inst_num in instance_number:
                print("\nSolving Instance ", inst_num)
                minizinc_manager = MiniZinc_Mangager(solver=solver, solver_name=solver_name)
                model_instance = minizinc_manager.create_model(path_to_model=model_path, data_instance_num=inst_num)
                result = minizinc_manager.solve_instance(model_instance=model_instance)
                sol_dict = minizinc_manager.solution_to_dict(solution=result.solution)
                minizinc_manager.save_to_JSON(sol_dict, filename=inst_num)
            

# This function calls the main code
main()
