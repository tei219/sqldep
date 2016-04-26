# 
# returns available parsers 
# 
function parsers {
	param( $versions );
	
	# choose 'LoadFrom' or 'LoadWithPartialName'
	#$sqldom = [System.Reflection.Assembly]::LoadFrom("C:\Program Files\Microsoft SQL Server\110\SDK\Assemblies\Microsoft.SqlServer.TransactSql.ScriptDom.dll");
	$sqldom = [System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.TransactSql.ScriptDom");
	if (-not $sqldom) {
		write-host "[ERR ] Please install the SQLDOM.MSI from the SQL 2012 Feature Pack web page http://www.microsoft.com/en-us/download/details.aspx?id=35580" -foregroundcolor red
		exit;
	}
	
	# select avilable parser
	$create_flgs = [ordered] @{};
	if ($versions -eq $null) {
		if ([bool] ($sqldom.gettypes() | where-object {$_.name -eq "TSql80Parser" } )) { $create_flgs.add("SQLServer2000", $true); }
		if ([bool] ($sqldom.gettypes() | where-object {$_.name -eq "TSql90Parser" } )) { $create_flgs.add("SQLServer2005", $true); }
		if ([bool] ($sqldom.gettypes() | where-object {$_.name -eq "TSql100Parser"} )) { $create_flgs.add("SQLServer2008", $true); }
		if ([bool] ($sqldom.gettypes() | where-object {$_.name -eq "TSql110Parser"} )) { $create_flgs.add("SQLServer2012", $true); }
		if ([bool] ($sqldom.gettypes() | where-object {$_.name -eq "TSql120Parser"} )) { $create_flgs.add("SQLServer2014", $true); }
	} else {
		# or select own
		foreach ($version in $versions) {
			if ( (($version -match  "80") -or ($version -match "2000")) -and (-not $create_flgs.contains("SQLServer2000")) ) { $create_flgs.add("SQLServer2000", $true); }
			if ( (($version -match  "90") -or ($version -match "2005")) -and (-not $create_flgs.contains("SQLServer2005")) ) { $create_flgs.add("SQLServer2005", $true); }
			if ( (($version -match "100") -or ($version -match "2008")) -and (-not $create_flgs.contains("SQLServer2008")) ) { $create_flgs.add("SQLServer2008", $true); }
			if ( (($version -match "110") -or ($version -match "2012")) -and (-not $create_flgs.contains("SQLServer2012")) ) { $create_flgs.add("SQLServer2012", $true); }
			if ( (($version -match "120") -or ($version -match "2014")) -and (-not $create_flgs.contains("SQLServer2014")) ) { $create_flgs.add("SQLServer2014", $true); }
		}
	}

	# create objects
	$parsers = [ordered] @{};
	foreach ($version in $create_flgs.keys) {
		if ($create_flgs[$version]) {
			switch($version) {
				"SQLServer2000" { $parsers.add($version,  $(new-object Microsoft.SqlServer.TransactSql.ScriptDom.TSql80Parser($false))); } 
				"SQLServer2005" { $parsers.add($version,  $(new-object Microsoft.SqlServer.TransactSql.ScriptDom.TSql90Parser($false))); } 
				"SQLServer2008" { $parsers.add($version, $(new-object Microsoft.SqlServer.TransactSql.ScriptDom.TSql100Parser($false))); } 
				"SQLServer2012" { $parsers.add($version, $(new-object Microsoft.SqlServer.TransactSql.ScriptDom.TSql110Parser($false))); } 
				"SQLServer2014" { $parsers.add($version, $(new-object Microsoft.SqlServer.TransactSql.ScriptDom.TSql120Parser($false))); } 
			}
		}
	}
	
	# returns hashtable, { SQLServer2000 => TSql80Parser-object, ... }
	return $parsers
}

Export-ModuleMember -Function parsers
