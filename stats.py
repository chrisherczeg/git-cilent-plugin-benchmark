import re
from git import Repo
import shutil
import os
import csv
import sys

def clone_git_repository(git_url, repo_dir):
    """
    Clones a Git repository from the specified URL to the specified directory.
    :param git_url: URL of the Git repository.
    :param repo_dir: Local directory where the repository will be cloned.
    """
    try:
        repo = Repo.clone_from(git_url, repo_dir)
        print(f"Repository cloned successfully to {repo_dir}")
        return repo
    except Exception as e:
        return Repo(repo_dir)
    
def parse_disk_random_write(file):
    """
    Parses the output of the Windows System Assessment Tool (WinSAT) for the Disk Random 16 Write speed.

    Args:
        output_text (str): The raw output text from WinSAT.

    Returns:
        float: The Disk Random 16 Write speed in MB/s.
    """

    if os.path.exists(file):
        try:
            with open(file, 'r', encoding='utf-16le') as original_file:
                content = original_file.read()
        except:
            with open(file, 'r', encoding='utf-8') as original_file:
                content = original_file.read()
    # Search for the line containing "Disk Random 16.0 Write"

        lines = content.split(">")
        for line in lines:
            if "Disk  Random 16.0 Write " in line:
                # Extract the speed value (e.g., "353.54 MB/s")
                speed_str = line.split()[-2]
                try:
                    # Convert the speed value to a float
                    speed = float(speed_str)
                    return speed
                except ValueError:
                    # Handle any conversion errors
                    return 1000

        # If the line is not found, return None
    return 1000

def get_test_times(repo, local_directory):
    all_branches = repo.heads + repo.remotes.origin.refs

    tests_map_exclusion = {}
    tests_map_non_exclusion = {}
    tests_map_exclusion_count = {}
    tests_map_non_exclusion_count = {}

    FilesName = ['RunMicrosoftJdkBenmarkMaster.log', "RunMicrosoftJdkBenmarkPerf.log",
                     'RunOpenJdkBenmarkMaster.log', 'RunOpenJdkBenmarkPerf.log']
    
    for file in FilesName:
        tests_map_exclusion[file] = {}
        tests_map_non_exclusion[file] = {}
        tests_map_exclusion_count[file] = {}
        tests_map_non_exclusion_count[file] = {}

    # Checkout each branch
    for branch in all_branches:
        print(f"Checking out branch: {branch.name}")
        branch.checkout()

        diskspeed = parse_disk_random_write(f'{local_directory}/disk_stats.log')
        print(f"Disk Speed: {diskspeed} MB/s")

        
        test_times_for_file = {}
        
        for file in FilesName:

            original_file_path = f'{local_directory}/{file}'
            if os.path.exists(original_file_path):
                try:
                    with open(original_file_path, 'r', encoding='utf-16le') as original_file:
                        content = original_file.read()
                except:
                    with open(original_file_path, 'r', encoding='utf-8') as original_file:
                        content = original_file.read()


                # utf8_file_path = 'C:/Users/chrisherczeg/SWEngineering/Final/benchmark_temp/RunMicrosoftJdkBenmarkMasterUtf8.log'
                # with open(utf8_file_path, 'w', encoding='utf-8') as utf8_file:
                #     utf8_file.write(content)

                # my_list = []  # Initialize an empty list to store dictionaries

                # with open('C:/Users/chrisherczeg/SWEngineering/Final/benchmark_temp/RunMicrosoftJdkBenmarkMasterUtf8.log', 'r') as f:
                #     lines = f.read()

                lines = f"{content}"
                # Extract time elapsed for each test using regular expressions
                pattern = r"Time elapsed: (\d+\.\d+) s -- in (.+)"
                matches = re.findall(pattern, lines)

                # Create a dictionary to store test names and their corresponding time elapsed
                test_times = {}
                
                for time, test_name in matches:
                    test_times[test_name] = float(time)

                # Print the results
                for test_name, time_elapsed in test_times.items():
                    # print(f"Test: {test_name}, Time Elapsed: {time_elapsed} seconds")
                    if branch.name.__contains__("non_exclusion"):
                        try:
                            tests_map_non_exclusion[file][test_name] = tests_map_non_exclusion[file][test_name] + (time_elapsed / diskspeed)
                            tests_map_non_exclusion_count[file][test_name] = tests_map_non_exclusion_count[file][test_name] + 1
                        except:
                            tests_map_non_exclusion[file][test_name] = (time_elapsed / diskspeed)
                            tests_map_non_exclusion_count[file][test_name] = 1

                    elif branch.name.__contains__("exclusion"):
                        try:
                            tests_map_exclusion[file][test_name] = tests_map_exclusion[file][test_name] + (time_elapsed / diskspeed)
                            tests_map_exclusion_count[file][test_name] = tests_map_exclusion_count[file][test_name] + 1
                        except:
                            tests_map_exclusion[file][test_name] = (time_elapsed / diskspeed)
                            tests_map_exclusion_count[file][test_name] = 1

    for file in FilesName:
        for key,value in tests_map_non_exclusion[file].items():
            print("Key value before: ", key, value)
            tests_map_non_exclusion[file][key] = tests_map_non_exclusion[file][key] / tests_map_non_exclusion_count[file][key]
            print("Key value after: ", key, tests_map_non_exclusion[file][key])
            print(tests_map_non_exclusion_count[file][key])

    for file in FilesName:
        for key,value in tests_map_exclusion[file].items():
            print("Key value before: ", key, value)
            tests_map_exclusion[file][key] = tests_map_exclusion[file][key] / tests_map_exclusion_count[file][key]
            print("Key value after: ", key, tests_map_exclusion[file][key])
            print(tests_map_exclusion_count[file][key])
    

    os.remove('git-client-plugin-non-exclusion.csv')
    os.remove('git-client-plugin-exclusion.csv')
    print(tests_map_non_exclusion)
    print(tests_map_non_exclusion_count)
    print(tests_map_exclusion)
    print(tests_map_exclusion_count)

    with open('git-client-plugin-non-exclusion.csv','w') as f:
        for file in FilesName:
            w = csv.DictWriter(f, tests_map_non_exclusion[file].keys())
            w.writeheader()
            w.writerow(tests_map_non_exclusion[file])

    with open('git-client-plugin-exclusion.csv','w') as f:
        for file in FilesName:
            w = csv.DictWriter(f, tests_map_exclusion[file].keys())
            w.writeheader()
            w.writerow(tests_map_exclusion[file])

# Specify the Git repository URL and the local directory for cloning
git_repository_url = 'https://github.com/chrisherczeg/git-cilent-plugin-benchmark.git'
local_directory = 'C:/Users/chrisherczeg/SWEngineering/Final/temp'
get_test_times(clone_git_repository(git_repository_url, local_directory), local_directory)
