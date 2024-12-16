#### This script is used to convert the .dat files to .dzn files
import os 

# Read the .dat file from the given path to it; Modify it and return it
def retrieve_dat_from_path(path_to_dat):
    """
    :param path_to_dat: It is the path pointing to a dat file
    :return: we return the modified information
    """
    with open(path_to_dat, 'r') as file:
        dzn_file = file.read()
    return dzn_file.splitlines()

def list_of_paths_of_dat():
    return sorted(os.listdir('Instances/Instances dat Format'))


# Defining a function that gets dat list and writes it to dzn file and saves it
def write_to_dzn_file(dat_info_list, path_to_save):
    with open(path_to_save, 'w') as file:
        first_time_flag = True
        for index, line in enumerate(dat_info_list):
            if index == 0:
                # Number of couriers
                file.write("num_courier = " + line + ";\n")
            elif index == 1:
                # Number of items
                file.write("num_item = " + line + ";\n")
            elif index == 2:
                # Courier capacity
                string_of_capacity_with_comma = ""
                for each_capacity in range(len(line.split(" ")) - 1):
                    string_of_capacity_with_comma += line.split(" ")[each_capacity] + ", "
                string_of_capacity_with_comma += line.split(" ")[-1]
                file.write("courier_capacity = [" + string_of_capacity_with_comma + "];\n")
            elif index == 3:
                # Item size
                string_of_weight_with_comma = ""
                for each_weight in range(len(line.split(" ")) - 1):
                    string_of_weight_with_comma += line.split(" ")[each_weight] + ", "
                string_of_weight_with_comma += line.split(" ")[-1]
                file.write("item_size = [" + string_of_weight_with_comma + "];\n")
            elif index >= 4 and index < 4 + int(dat_info_list[1]):
                # Distance Matrix
                if first_time_flag:
                    first_time_flag = False
                    file.write("distance_mat = [")
                string_of_value_with_comma = ""
                for each_value in range(len(line.split(" ")) - 1):
                    string_of_value_with_comma += line.split(" ")[each_value] + ", "
                file.write("| " + string_of_value_with_comma + "\n")
            else:
                string_of_value_with_comma = ""
                for each_value in range(len(line.split(" ")) - 1):
                    string_of_value_with_comma += line.split(" ")[each_value] + ", "
                file.write("| " + string_of_value_with_comma + "\n")
                file.write("|];\n")
            

# Getting path to dat instances
list_of_paths_of_dat = list_of_paths_of_dat()  

parent_path_to_dat = "Instances/Instances dat Format/"
saving_path_to_dzn = "Instances/Instances dzn Format/"

for index, each_dat in enumerate(list_of_paths_of_dat):
    list_of_each_dat_info = retrieve_dat_from_path(parent_path_to_dat+each_dat)
    write_to_dzn_file(list_of_each_dat_info, saving_path_to_dzn+f"Instance{str(index+1).zfill(2)}.dzn")

