param( 
	[switch] $q = $false, #to show description of parse error.
	[switch] $r = $false  #to return check result. 
)

function parse_testr {
	param ( 
		$source,
		[bool] $summary_only = $false,
		[bool] $check_result = $true,
		[bool] $skip_largefile = $true,
		$largefile_size = 3mb
	);

	import-module -force .\modules\files_selectr.psm1
	import-module -force .\modules\parsers.psm1

	# parsers() imported from parsers.psm1
	$parsers = parsers;
	$checks = @{};
	foreach ($version in $parsers.keys) { $checks.add($version, $false); }

	# files_selectr() imported from files_selectr.psm1
	$files = files_selectr($source) -filter "*.sql";

	$return_flg = $true;
	
	$files | foreach {
		if (((get-item $_.fullname).length -gt $largefile_size) -and ($skip_largefile)) {
			write-host ("[WARN] "+$_.fullname+" filesize is too large, abort to parse.") -foregroundcolor yellow;
			$checks_summary = $false;
		} else {
			$checks_summary = $true;
			foreach ($version in $parsers.keys) {
				[System.IO.TextReader] $reader = New-Object System.IO.StreamReader($_.fullname);
				$error = $null
				$sqlfragments = $parsers[$version].parse($reader, [ref] $error);
				$reader.dispose();
				
				if ($error) {
					if (-not $summary_only) {
						$error | foreach { 
							write-host ("[WARN]", (($version, $_.line, $_.message) -join ", ") ) -foregroundcolor yellow;
						}
					}
					$checks[$version] = $false;
					$checks_summary = $false;
				} else {
					$checks[$version] = $true;
				}
			}
			if ($checks_summary) {
				write-host ($_.fullname, " (", ($checks.keys -join ", "), ") = (", ($checks.values -join ", "), ")");
			} else {
				write-host ($_.fullname, " (", ($checks.keys -join ", "), ") = (", ($checks.values -join ", "), ")") -foregroundcolor yellow;
			}
		}
		$return_flg = ($return_flg -and $checks_summary);
	}
	
	if ($check_result) {
		return $return_flg;
	}
}

#
# Usage: 
#  .\parse_testr.ps1 source [-q] [-r]
#
#  ex.
#  .\parse_testr.ps1 "select * from tab"
#  .\parse_testr.ps1 file
#  .\parse_testr.ps1 path\to\
#

#script starts here
if ($args.count -gt 0) {
	parse_testr -source $args[0] -summary_only $q -check_result $r
}
