#!/bin/bash
error_count=0
total_count=0

for file in $(find . -name "*.xml"); do
    ((total_count++))
    echo -n "Checking $file... "
    
    if xmllint --noout "$file" 2>/dev/null; then
        echo "OK"
    else
        echo "FAILED"
        ((error_count++))
    fi
done

echo "Summary: $error_count errors out of $total_count files"
exit $error_count