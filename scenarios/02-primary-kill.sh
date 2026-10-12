SCENARIO=02-primary-kill
TITLE="Primary postmaster killed (kill -9)"
inject() {
    nexec pg1 lab-node kill-postmaster
}
