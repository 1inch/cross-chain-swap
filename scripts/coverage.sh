set -e # exit on error

mkdir -p coverage

# generates lcov.info
forge coverage --report lcov --ir-minimum --report-file coverage/lcov.info

# Filter out node_modules, test, and mock files
lcov \
    --rc branch_coverage=1 \
    --remove coverage/lcov.info \
    --output-file coverage/filtered-lcov.info \
    "*test*" "contracts/mocks/*"

# Generate summary
lcov \
    --rc branch_coverage=1 \
    --list coverage/filtered-lcov.info

# Generate html report
if [ "$CI" != "true" ]
then
    genhtml \
        --rc branch_coverage=1 \
        --keep-going \
        --output-directory coverage \
        coverage/filtered-lcov.info
fi
