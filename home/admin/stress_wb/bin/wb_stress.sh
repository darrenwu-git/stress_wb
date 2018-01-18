#!/bin/bash

set -ex

STRESS_WB_DIR=/home/admin/stress_wb
exec &> >(tee -a "$STRESS_WB_DIR/data/wb_stress.log")

STRESS_WB_CONF=/home/admin/stress_wb/config
STRESS_WB_RUNTIME=/home/admin/stress_wb/runtime
STRESS_WB_PASS_FILE=/home/admin/stress_wb/pass
STRESS_WB_FAIL_FILE=/home/admin/stress_wb/fail

. $STRESS_WB_CONF
. $STRESS_WB_RUNTIME || true

lsusb_lspci_orig() {
    echo "Save first lsusb and lspci log"
    LD_LIBRARY_PATH=$STRESS_WB_DIR/lib $STRESS_WB_DIR/bin/lsusb > $STRESS_WB_DIR/data/lsusb_original 2>/dev/null || true
    LD_LIBRARY_PATH=$STRESS_WB_DIR/lib $STRESS_WB_DIR/bin/lspci > $STRESS_WB_DIR/data/lspci_original || true
}

reboot_loop() {
    echo "Sleep $STRESS_BOOT_WAIT_DELAY sec and reboot"
    sleep $STRESS_BOOT_WAIT_DELAY
    reboot
}

check_lsusb_lspci() {
    echo "Wait $STRESS_BOOT_UP_DELAY sec then check lsusb and lspci"
    sleep $STRESS_BOOT_UP_DELAY
    error=
    LD_LIBRARY_PATH=$STRESS_WB_DIR/lib $STRESS_WB_DIR/bin/lsusb > $STRESS_WB_DIR/data/lsusb_test 2>/dev/null
    LD_LIBRARY_PATH=$STRESS_WB_DIR/lib $STRESS_WB_DIR/bin/lspci > $STRESS_WB_DIR/data/lspci_test

    set +e
    diff $STRESS_WB_DIR/data/lsusb_original $STRESS_WB_DIR/data/lsusb_test
    if [ $? -ne 0 ] ; then
      diff $STRESS_WB_DIR/data/lsusb_original $STRESS_WB_DIR/data/lsusb_test > $STRESS_WB_FAIL_FILE
      echo "lsusb mismatch during cycle $LAST_ITERATION" >> $STRESS_WB_FAIL_FILE
      error=true
    fi

    diff $STRESS_WB_DIR/data/lspci_original $STRESS_WB_DIR/data/lspci_test
    if [ $? -ne 0 ] ; then
      diff $STRESS_WB_DIR/data/lspci_original $STRESS_WB_DIR/data/lspci_test >> $STRESS_WB_FAIL_FILE
      echo "lspci mismatch during cycle $LAST_ITERATION" >> $STRESS_WB_FAIL_FILE
      error=true
    fi
    set -e

    if [ "$error" = true ];then
	  echo "device gone... see the log: $STRESS_WB_FAIL_FILE"
      exit
    fi
}

if [ "$1" == "restart" ] && [ -f $STRESS_WB_RUNTIME ]; then
    rm $STRESS_WB_RUNTIME
    LAST_ITERATION=
    if [ -f $STRESS_WB_PASS_FILE ];then
        rm $STRESS_WB_PASS_FILE
    fi
    if [ -f $STRESS_WB_FAIL_FILE ];then
        rm $STRESS_WB_FAIL_FILE
    fi
fi

#First cycle
if [ -z $LAST_ITERATION ]; then
    LAST_ITERATION=0
    lsusb_lspci_orig
else #other cycles
    echo "WB stress cycle $LAST_ITERATION"
    check_lsusb_lspci
fi

if [ $LAST_ITERATION -lt $STRESS_BOOT_ITERATIONS ]; then
    LAST_ITERATION=$((LAST_ITERATION + 1))
    sudo echo "LAST_ITERATION=$LAST_ITERATION" > $STRESS_WB_RUNTIME
    reboot_loop
elif [ ! -z $LAST_ITERATION ]; then
    echo "WB stress test done! Pass!" > $STRESS_WB_PASS_FILE
fi
