MAS=../../compiler/mas
VMCPU_core=`find .. -name VMCPU_core`

if [ ! "$VMCPU_core" ]; then echo "Cannot find VMCPU_core"; exit 1; fi

MAS=$MAS VMCPU_core=$VMCPU_core make tests
