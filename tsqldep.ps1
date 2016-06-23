<#
.SYNOPSIS
returns 'parse result', 'formatted', 'parse tree', 'use tables', 'CRUD table' table of input transact-sql.

.DESCRIPTION
source argument specifies the string such as "select * from table" ,file or directory.
Each column of the table is as follows:
	type := 'string' or 'file'
	source := in the case of 'string' query , otherwise, it is the file name.
	parse_error := in the case of 'parse error' object list of error, otherwise, it is null.
	fragment := not in the case of 'parse error' [Microsoft.SqlServer.TransactSql.ScriptDom.TSqlScript], otherwise, it is null.
	formatted := formatted sql string.
	tree := formatted string of [Microsoft.SqlServer.TransactSql.ScriptDom.TSqlScript].
	tables := use tables list. tables has MultiPartIdentifier like 'SVR.db.schema.table'
	query := each query of statement in source.
	stmt := each [Microsoft.SqlServer.TransactSql.ScriptDom.TSqlScript] of query.
Please refer to the EXAMPLE each function respectively.

.EXAMPLE
tsqldep.ps1 "select * from  "
'-op parse' or '-p' option shows 'parse result' table. default operate.
"parse_error" reported parse errors.
result has rows by each source. if hard to see columns, use 'format-list'

type     source                                   parse_error                                                  fragment
----     ------                                   -----------                                                  --------
string   select * from                            Microsoft.SqlServer.TransactSql.ScriptDom.ParseError

.EXAMPLE
tsqldep.ps1 -f "select * from a; select * from b;"
'-op format' or '-f' option shows 'formatted' table.
"formatted" reported formatted sql string.
result has rows by each statements (shows in 'query'). if hard to see columns, use 'format-list'
type     source                                   formatted
----     ------                                   ---------
string   select * from a; select * from b;        SELECT *...

.EXAMPLE
tsqldep.ps1 -r "select * from a; select * from b;"
'-op tree' or '-r' option shows 'parse tree' table.
result has rows by each statements (shows in 'query'). if hard to see columns, use 'format-list'

type     source                                   tree                                                         query
----     ------                                   ----                                                         -----
string   select * from a; select * from b         {QueryExpression=Microsoft.SqlServer.TransactSql.ScriptDo... select * from a;
string   select * from a; select * from b         {QueryExpression=Microsoft.SqlServer.TransactSql.ScriptDo... select * from b

.EXAMPLE
tsqldep.ps1 -t "select * from a; select * from b"
'-op tables' or '-t' option shows 'use tabales' table.
"tables" reported in the fully qualified name contained by "."
'ServerIdentifier', 'DatabaseIdentifier', 'SchemaIdentifier' and 'BaseIdentifier'
result has rows by each statements (shows in 'query'). if hard to see columns, use 'format-list'

type     source                                   tables                                                       query
----     ------                                   ------                                                       -----
string   select * from a; select * from b         ...a                                                         select * from a;
string   select * from a; select * from b         ...b                                                         select * from b


.EXAMPLE
.\tsqldep.ps1 -c "select * from a; update b set a=1; delete c; create table d(id int)"
'-op crud' or '-c' option shows CRUD table.

select * from a; update b set a=1; delete c; create table d(id int) :
C : ...d
R : ...a
U : ...b
D : ...c


.OUTPUTS
returns results with table format. 
It is easy to see when you see the results directly. 
such as :
PS C:\>$(tsqldep.ps1 -r "select * from a;").tree

.LINK
https://msdn.microsoft.com/ja-jp/library/hh215705.aspx

.NOTES

#>

# params ######################################################################
[CmdletBinding()]
#to operate option order: -p > -f > -t > -c > -r > parse > format > tables > crud > tree
param (
	[parameter(Mandatory=$true, helpmessage="input ""tsql-string"" or file/directory to parse.")] [alias('s')] [string] $source = $args[0],
	[parameter()] [ValidateSet( 'crud','tables','parse','tree','format' )] [string] $op = "parse",
	[switch] $c = $false,
	[switch] $t = $false,
	[switch] $p = $false,
	[switch] $r = $false,
	[switch] $f = $false,
	[switch] $desc = $false,
	[parameter()] [ValidateSet( 'TSql80Parser','TSql90Parser','TSql100Parser','TSql110Parser','TSql120Parser' )] [string] $version = "TSql110Parser"
)

if ($r) { $op = "tree" }
if ($c) { $op = "crud" }
if ($t) { $op = "tables" }
if ($f) { $op = "format" }
if ($p) { $op = "parse" }

# import ######################################################################

# workflows ###################################################################

# functions ###################################################################
function ErrorExit {
	"Error, Exit"
	Exit;
}

function mktable {
	param ( $ColumnArray )
	$o = New-Object PSObject
	$ColumnArray | % {$o | Add-Member -MemberType NoteProperty -Name $_ -Value $null}
	$o
}

function selectr {
	param ( [parameter(Mandatory=$true)] $source )

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

	switch($type) {
		"string" {
			$tab += mktable( @("type","source") ) | % { $_.type = $type; $_.source = $source; $_ }
		}
		"file" {
			$tab += mktable( @("type","source") ) | % { $_.type = $type; $_.source = $source; $_ }
		}
		"directory" {
			$tab += get-childitem -file -filter "*.sql" -path $source -recurse | select-object fullname | % {
				$fullname = $_.fullname; 
				mktable( @("type","source") ) | % { $_.type = "file"; $_.source = $fullname; $_ }
			}
		}
	}

	return $tab;
}

function showtree {
	param( $stmt, $indent=1 )
	if ($indent -eq 1) { $statement.gettype().name+"="+$statement.gettype()}
	$stmt | get-member -membertype property | 
		? { $_.Name -notin @("StartLine","StartOffset","FragmentLength","StartColumn","FirstTokenIndex","LastTokenIndex","ScriptTokenStream") } | 
			foreach { 
				if ($stmt.($_.name) -ne $null) {
					" "*$indent + $(($_.name, $stmt.($_.name)) -join "=")
					showtree $stmt.($_.name) $($indent+1)
				}
			}
}

function gettables {
	param( $stmt, $alias)
	$stmt | get-member -membertype property | 
		? { $_.name -notin @("StartLine","StartOffset","FragmentLength","StartColumn","FirstTokenIndex","LastTokenIndex","ScriptTokenStream") } | 
			% { 
					if ($stmt.($_.name) -ne $null) {
						if ($_.name -eq "TableReferences") { 
							$stmt.($_.name) | % { gettables $_; }
						} else {
							if($stmt.($_.name).DataType) {
								#datatype
							} else {
								if ($stmt.($_.name).gettype().basetype.name -eq "MultiPartIdentifier") {
									#if (($stmt.($_.name).BaseIdentifier.QuoteType -eq "NotQuoted") -and ($stmt.($_.name).BaseIdentifier.Value -inotin $reserved_keywords)) {
										showtables $stmt.($_.name) $stmt
									#}
								} else {
									if ($stmt.($_.name).BaseIdentifier) {
										$stmt.($_.name) | % { $(($_.ServerIdentifier.value, $_.DatabaseIdentifier.value, $_.SchemaIdentifier.value, $_.BaseIdentifier.value) -join ".") + $alias }
									}
								}
								if ($stmt.Alias) {
									gettables $stmt.($_.name) " as "+$stmt.Alias.value
								} else {
									gettables $stmt.($_.name)
								}
							}
						}
					}
				}
}

function showtables {
	param( $stmt, $parent )
	if ($parent.Alias) {
		$alias = " as "+$parent.Alias.value
	}
	$tabname = $stmt | % { $(($_.ServerIdentifier.value, $_.DatabaseIdentifier.value, $_.SchemaIdentifier.value, $_.BaseIdentifier.value) -join ".") + $alias }
	if($parent.parameters) {
		$tabname = $tabname + "()"
	}
	$tabname
}

function showquery {
	param( $stmt )
	$q = ""
	for ($i = $stmt.FirstTokenIndex; $i -le $stmt.LastTokenIndex; $i++) {
		$q += $stmt.ScriptTokenStream[$i].text;
	}
	$q
}

function getcrud {
	param ( $stmt, $stmts )
	switch ($stmt.gettype().name) {
		"CreateTableStatement" { $stmts.tables | % { $crud[$stmts.source]["C"] += $_; } }
		"DropTableStatement" { $stmts.tables | % { $crud[$stmts.source]["D"] += $_; } }
		"SelectStatement" { 
				if ($stmts.stmt.Into) {
					$into = $(showtables $stmt.Into)
				}
				$stmts.tables | % { 
					if ($_ -ne $into) {
						$crud[$stmts.source]["R"] += $_; 
					} else {
						$crud[$stmts.source]["C"] += $into; 
					}
				}; 
				$into = $null;
			}
		"InsertStatement" {
			if ($stmts.stmt.InsertSpecification.Target.SchemaObject) {
				$into = $(showtables $stmt.InsertSpecification.Target.SchemaObject)
			}
				$stmts.tables | % { 
					if ($_ -ne $into) {
						$crud[$stmts.source]["R"] += $_; 
					} else {
						$crud[$stmts.source]["C"] += $into; 
					}
				}; 
				$into = $null;
		}
		"UpdateStatement" { 
			$target = $(showtables $stmt.UpdateSpecification.Target.SchemaObject)
			$stmts.tables | % { 
				if ($_ -ne $target) {
					$crud[$stmts.source]["R"] += $_; 
				} else {
					$crud[$stmts.source]["U"] += $target; 
				}
			};
			$target = $null
		}
		"DeleteStatement" {
			$target = $(showtables $stmt.DeleteSpecification.Target.SchemaObject)
			$stmts.tables | % { 
				if ($_ -ne $target) {
					$crud[$stmts.source]["R"] += $_; 
				} else {
					$crud[$stmts.source]["D"] += $target; 
				}
			};
			$target = $null
		}
		"IfStatement" {
			getcrud $stmt.Predicate $stmts
			getcrud $stmt.ThenStatement $stmts
			if ($stmt.ElseStatement) { getcrud $stmt.ElseStatement $stmts }
		}
		"ExistsPredicate" {
			if ($stmt.Subquery.QueryExpression.FromClause) {
				#gettables $stmt.Subquery.QueryExpression $stmts
			} 
		}
		default { 
			$stmt.gettype().name
		}
	}
}

# main ########################################################################
# create $parser
$sqldom = [System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.TransactSql.ScriptDom");
if (-not $sqldom ) { ErrorExit; } #$sqldom.gettypes()

if ([bool] ($sqldom.gettypes() | where-object {$_.name -eq $version } )) {
	$parser = new-object Microsoft.SqlServer.TransactSql.ScriptDom.$version($false);
} else {
	write-host ("[ERR ] can't create '$version'. can't continue.") -foregroundcolor red;
	exit;
}

# string or file or directory
$sources = selectr($source)

# do
$er = $false
$buffertable += foreach ($sql in $sources) { 
	$errors = $null
	#parse
	if ($sql.type -eq "string") {
		$fragment = $parser.parse([System.IO.StringReader] $sql.source, [ref] $errors);
	} else {
		[System.IO.TextReader] $reader = New-Object System.IO.StreamReader($sql.source);
		write-host "parsing ... " $sql.source
		$fragment = $parser.parse($reader, [ref] $errors);
		$reader.dispose();
	}
	if ($errors) {
		write-host ("[WARN] Parse error: ", $sql.source ) -foregroundcolor yellow;
		$errors | % { 
			write-host ("[WARN]", (($_.line, $_.message) -join ", ")) -foregroundcolor yellow;
		}
		$er = $true;
		mktable( @("type","source","parse_error","fragment") ) | % { $_.type = $sql.type; $_.source = $sql.source; $_.parse_error = $errors; $_.fragment = $null; $_ }
	} else {
		mktable( @("type","source","parse_error","fragment") ) | % { $_.type = $sql.type; $_.source = $sql.source; $_.parse_error = $null; $_.fragment = $fragment; $_ }
	}
}

if ($op -eq "parse") { 
	$buffertable
	exit; 
}
$sources = $buffertable
$buffertable = $null

if ($er) {
	write-host ("[ERR ] detect parse error. can't continue.") -foregroundcolor red;
	exit;
}

if ($op -eq "format") {
	$sources | % {
		$str = $_;
		$sql = ""
		$generator = new-object Microsoft.SqlServer.TransactSql.ScriptDom.Sql110ScriptGenerator;
		$generator.GenerateScript($str.fragment, [ref] $sql);
		mktable( @("type","source","formatted") ) | % { $_.type = $str.type; $_.source = $str.source; $_.formatted = $sql; $_ }
	}
	exit;
}
#
#Microsoft.SqlServer.TransactSql.ScriptDom.TSqlFragment
# + Microsoft.SqlServer.TransactSql.ScriptDom.TSqlScript <- $sql.fragment
# + Microsoft.SqlServer.TransactSql.ScriptDom.SelectElement
#  + Microsoft.SqlServer.TransactSql.ScriptDom.SelectSetVariable
# + Microsoft.SqlServer.TransactSql.ScriptDom.TSqlBatch <- $sql.fragment.batches
# + Microsoft.SqlServer.TransactSql.ScriptDom.TSqlStatement <- $sql.fragment.batches[]
#

# gettables and getcrud
$buffertable += foreach ($sql in $sources) {
	foreach ($batch in $sql.fragment.batches) {
		foreach ($statement in $batch.statements) {
			switch($op) {
				"tree" {
					mktable( @("type","source","tree","query","stmt") ) | % { $_.type = $sql.type; $_.source = $sql.source; $_.query = $(showquery $statement); $_.tree = $(showtree $statement); $_.stmt = $statement; $_ }
				}
				default {
					mktable( @("type","source","tables","query","stmt") ) | % { $_.type = $sql.type; $_.source = $sql.source; $_.query = $(showquery $statement); $_.tables = $(gettables $statement); $_.stmt = $statement; $_ }
					#gettables $statement
				}
			}
		}
	}
}
if ($op -eq "tree") { 
	if (-not $desc) {
		$buffertable | select type, source, tree, query
	} else {
		$buffertable 
	}
	exit; 
}

if ($op -eq "tables") { 
	if (-not $desc) {
		$buffertable | select type, source, tables, query
	} else {
		$buffertable 
	}
	exit; 
}


# crud
$crud = @{};
$buffertable | % {
	$stmts = $_;
	if (-not $crud.contains($stmts.source)) {
		$crud.add($stmts.source, @{C = @();R = @();U = @();D = @(); });
	}
	getcrud $stmts.stmt $stmts
}

foreach ($key in $crud.Keys) {
	$key+" : "
	foreach ($k in $crud[$key].keys) {
		$k+" : "+$( ($crud[$key][$k] | sort -uniq) -join ",")
	}
	" "
}
