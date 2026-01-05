#=======================================
# APP
#=======================================

get_space_info() {
	df -B1 --output=target,size,avail,pcent | tail -n +2 | awk '$1 ~ /^\/$/'
}
