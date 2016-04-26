function files_selectr {
	param ( $source, $filter = "*" );

	if ($source) {
		$type = "string";
		if ((test-path $source -isvalid)) {
			if (test-path $source) {
				if (test-path $source -pathtype container) { 
					$type = "directory"
				} else {
					$type = "file"
				}
			}
		}
	} else {
		write-host "[ERR ] require source" -foregroundcolor red
		exit;
	}

	$files = @();
	switch($type) {
		"string" {
			new-item .\tmp -itemtype directory -force | out-null
			echo $source | out-file .\tmp\tmp.sql
			$files = get-item ".\tmp\tmp.sql" | select fullname;
		}
		"file" {
			$files = get-item $source | select fullname;
		}
		"directory" {
			$files = get-childitem $source -recurse -filter $filter | select fullname;
		}
	}
	return $files;
}

Export-ModuleMember -Function files_selectr
