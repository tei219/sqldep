# 
# returns boolean
# ex. inarray_match pattern_array target
#  if target match pattern in pattern_array, return true.
# 
function inarray_match {
	param ( 
		[Parameter(Mandatory=$True,Position=1)] [array] $pattern_array, 
		[Parameter(Mandatory=$True,Position=2)] [string] $target 
	);
	
	foreach ($pattern in $pattern_array) {
		if ($pattern -match $target) {
			return $true;
		}
	}
	return $false;
}

# 
# returns boolean
# ex. inarray_match_equal pattern_array target
#  if target equal pattern in pattern_array, return true.
#
function inarray_match_equal {
	param ( 
		[Parameter(Mandatory=$True,Position=1)] [array] $pattern_array, 
		[Parameter(Mandatory=$True,Position=2)] [string] $target 
	);
	
	foreach ($pattern in $pattern_array) {
		if ($pattern -eq $target) {
			return $true;
		}
	}
	return $false;
}

Export-ModuleMember -Function inarray_match
Export-ModuleMember -Function inarray_match_equal
