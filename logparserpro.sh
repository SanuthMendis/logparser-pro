#!/bin/bash

#Student Name: Sanuth Sithmaka Mendis Paskuwalhandi
#Student ID: 10652513

# This section initaialize the variables for the flags
# When running the script without any flags, the user will be prompted to provide the input file name
single_search=""
double_search=()
zip_flag=false

# The getopts command is used to parse the flags and their values
while getopts ":s:d:z" opt; do
# The case statement is used to check the flag and assign the value to the corresponding variable
  case $opt in
    # The -s flag is used to search for a single term
    s) single_search="$OPTARG" ;;
    # The -d flag is used to search for two terms
    d) IFS=',' read -ra double_search <<< "$OPTARG" ;;
    # The -z flag is used to zip the output file
    z) zip_flag=true ;;
    # The default case is used to exit the script if no valid flags are provided
    *) echo "No valide flags provided. Exiting..."; exit 1 ;;  
  esac
done

# In this section, the script checks whether the user has provided any flags.
# -eq is used to check if the number of arguments is equal to 0
if [[ $# -eq 0 ]]; then
  echo "Run default operation only"
  read -p "Please provide name of the source web log and results output file (e.g. input_file output_file): " input_file output_file
 
  # While loop is used to check if the input file exists
  while [[ ! -f "$input_file" ]]; do
    echo "No such file or directory: $input_file"
    echo "You need to provide the name of existing web log .csv file, e.g."
    ls *.csv
    echo "Please try again"
    read -p "Please provide the name of an existing web log file (e.g. input_file): " input_file
  done
fi


# Checks whether the single_search variable contains a comma.
if [[ $single_search =~ "," ]]; then
  echo "Error: Single search term cannot contain a multiple values or comma."
  exit 1
fi


# Checks whether the -z flag is used with the -s or -d flag.
if [[ $zip_flag == true && -z $single_search && ${#double_search[@]} -eq 0 ]]; then
  echo "Error: Search option -s or -d must be used in this context. Exiting..."
  exit 1
fi


# Checks whether the -s and -d flags are used together.
if [[ -n $single_search && ${#double_search[@]} -gt 0 ]]; then
  echo "Error: -s and -d flags can't be used together. Exiting..."
  exit 1
fi


# Checks whether the double_search variable contains two arguments separated by a comma.
if [[ ${#double_search[@]} -eq 1  || ${#double_search[@]} -gt 2 ]]; then
    echo "Error: -d requires two arguments separated by a comma, e.g. arg1,arg2. Exiting..."
    exit 1
fi


# Prompts the user to provide the name of the input file.
if [[ -n $single_search || ${#double_search[@]} -eq 2 ]]; then
  read -p "Please provide the name of the source web log file: " input_file

  
  # This while loop is used to check if the input file exists.
  while [[ ! -f "$input_file" ]]; do
    echo "You need to provide the name of existing web log .csv file, e.g."
    ls *.csv
    echo "Please try again"
    read -p "Please provide the name of an existing web log file: " input_file
  done
fi


# Generates a timestamp and assigns it to the output_file variable.
if [[ -z $output_file ]]; then
  timestamp=$(date +%Y_%m_%d_%H_%M_%S)  # Generate timestamp

# Check if single_search or double_search is provided
  if [[ -n $single_search ]]; then
    output_file="${timestamp}_fltarg_${single_search}.csv"
  elif [[ ${#double_search[@]} -eq 2 ]]; then
    output_file="${timestamp}_fltarg_${double_search[0]}_${double_search[1]}.csv"
  else
  # Default output file name
    output_file="${timestamp}_results.csv"
  fi
fi

echo "Processing..."

# Write header to output file
echo "IP,Date,Method,URL,Protocol,Status" > "$output_file"

# Assign double_search values to variables
d_1=${double_search[0]}  
d_2=${double_search[1]}

# Filter records and send to output file
awk -F, -v s_term="$single_search" -v d_term1="$d_1" -v d_term2="$d_2" '
  NR == 1 && $1 ~ /IP/ { next }  # Skip the header
  {
    line = $0 
    ip = $1
    # Split Date and Time 
    split($2, dt, "[: ]")  
    date = substr(dt[1], 2)  # Remove [ from the date
    
    # Split URL
    split($3, req, " ")
    method = req[1]
    gsub(/^\//, "", req[2])
    gsub(/\?.*$/, "", req[2])  # Remove query parameters
    url = req[2]
    protocol = req[3]
    status = $4
    
    # Filter 
    if (s_term && line !~ s_term) next
    if (d_term1 && d_term2 && !(line ~ d_term1) || line !~ d_term2) next

    # Print Output
    print ip "," date "," method "," url "," protocol "," status
  }
' "$input_file" >> "$output_file"


# Print Record count
row_count=$(($(wc -l < "$output_file") - 1))
# -gt is used to check if the row_count is greater than 0
if [ "$row_count" -gt 0 ]; then
    echo "$row_count records processed and the result written to $output_file as requested"
else 
    echo "No matching records found."
    rm $output_file # Remove file if it is empty
fi 

# Compress the result file
if $zip_flag; then

  if [ "$row_count" -eq 0 ]; then
   echo "No zip file created."
   exit 0 
  fi
  # Create zip file
  zip_file="${output_file%.csv}.zip"
  result=$(zip "$zip_file" "$output_file")
  # Check if the zip command was successful
  if [ "$?" -eq 0 ]; then
   echo "The result file has been zipped into $zip_file as requested"
  else
   echo "Error: Failed to zip the output file"
   exit 1
  fi
fi

exit 0 
