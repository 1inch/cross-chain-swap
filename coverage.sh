set -e # exit on error

# generates coverage/lcov.info
# yarn hardhat coverage

mkdir -p coverage

# generates foundry_lcov.info
forge coverage --report lcov --ir-minimum --report-file coverage/foundry_lcov.info

# Foundry uses relative paths but Hardhat uses absolute paths.
# Convert absolute paths to relative paths for consistency.
# sed -i -e 's/\/.*cross-chain-swap.//g' coverage/lcov.info

# Merge lcov files
# lcov \
#     --rc branch_coverage=1 \
#     --add-tracefile coverage/lcov.info \
#     --add-tracefile coverage/foundry_lcov.info \
#     --output-file coverage/merged-lcov.info

# Filter out node_modules, test, and mock files
lcov \
    --rc branch_coverage=1 \
    --remove coverage/foundry_lcov.info \
    --output-file coverage/filtered-lcov.info \
    "*test*"
    # "*node_modules*" "*test*" "*mock*"
    

# Generate summary
lcov \
    --rc branch_coverage=1 \
    --list coverage/filtered-lcov.info

# Open more granular breakdown in browser
if [ "$CI" != "true" ]
then
    genhtml \
        --rc branch_coverage=1 \
        --keep-going \
        --output-directory coverage \
        coverage/filtered-lcov.info
    # open combined_coverage/index.html
fi
