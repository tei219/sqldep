<#
.SYNOPSIS
入力された transact-sql の '解析結果'/'整形結果'/'解析ツリー'/'使用テーブル一覧'/'CRUD表' を出力します

.DESCRIPTION
transact-sql を ScriptDom を利用して解析します
入力には "select * from table" のような文字列 または ファイル, ディレクトリ を指定します
それぞれの出力結果は以下のカラムを持ちます
	-p '解析結果' := type, source, parse_error, fragment
	-f '整形結果' := type, source, formatted
	-r '解析ツリー' := type, source, tree, query
	-t '使用テーブル一覧' := type, source, tables, query
	-c 'CRUD表' := C,R,U,D
それぞれのカラムは下記のとおりです
	type := 'string' または 'file' 入力ソースの形式を示します
	source := type が 'string' の場合は SQLクエリ, その他の場合は ファイル名 を示します
	parse_error := 解析エラーが検出された場合はエラーリストとして ScriptDom.ParseError オブジェクト, その他の場合は null を示します
	fragment := 解析エラーがない場合はフラグメントとして ScriptDom.TSqlScript オブジェクト, その他の場合は null を示します
	formatted := 整形済みの SQLクエリ を示します
	tree := ScriptDom.TSqlScript オブジェクトをツリー形式にした文字列を示します
	tables := クエリで使用しているテーブルの一覧を示します。テーブルは instance.db.schema.table のような MultiPartIdentifier を示します
	query := 解析されたSQLクエリを示します
	stmt := 解析されたSQLクエリ内のステートメントオブジェクトを示します
オプション version で解析するエンジンを選択できます
オプション desc で stmt 列を表示できます
オプション tablelist で使用テーブルの一覧を tablelist フォルダ配下へ出力します
詳細は EXAMPLE を参照してください

.EXAMPLE
.\tsqldep.ps1 "select * from  "
results:
type     source                                   parse_error                                                  fragment
----     ------                                   -----------                                                  --------
string   select * from                            Microsoft.SqlServer.TransactSql.ScriptDom.ParseError

オプション -op parse または -p を使用して解析結果を出力します。これはデフォルトの動作です。
'parse_error' 列で解析結果を確認できます。

.EXAMPLE
.\tsqldep.ps1 -f "select * from a; select * from b;"
results:
type     source                                   formatted
----     ------                                   ---------
string   select * from a; select * from b;        SELECT *...

オプション -op format または -f を使用して整形結果を出力します。
'formatted' 列で整形結果を確認できます。整形方は sqldom の標準に準拠します。


.EXAMPLE
.\tsqldep.ps1 -r "select * from a; select * from b;"
results:
type     source                                   tree                                                         query
----     ------                                   ----                                                         -----
string   select * from a; select * from b         {QueryExpression=Microsoft.SqlServer.TransactSql.ScriptDo... select * from a;
string   select * from a; select * from b         {QueryExpression=Microsoft.SqlServer.TransactSql.ScriptDo... select * from b

オプション -op format または -f を使用して解析ツリー結果を出力します。
結果はステートメント毎に出力します。


.EXAMPLE
tsqldep.ps1 -t "select * from a; select * from b"
results:
type     source                                   tables                                                       query
----     ------                                   ------                                                       -----
string   select * from a; select * from b         ...a                                                         select * from a;
string   select * from a; select * from b         ...b                                                         select * from b

オプション -op tables または -t を使用して使用テーブル一覧を出力します。
テーブルは完全な識別子( server_name . database_name . schema_name . object_name )をもちます。
結果はステートメント毎に出力します。



.EXAMPLE
.\tsqldep.ps1 -c "select * from a; update b set a=1; delete c; create table d(id int)"
results:
select * from a; update b set a=1; delete c; create table d(id int) :
C : ...d
R : ...a
U : ...b
D : ...c

オプション -op crud または -c を使用してCRUD表を出力します。
※これはテスト段階の機能です

.EXAMPLE
(.\tsqldep.ps1 -f "select * from a; select * from b;").formatted
results:
SELECT *
FROM   a;

SELECT *
FROM   b;

出力結果のオブジェクトに直接アクセスすることによって、結果が見やすくなります。

.INPUTS
文字列またはファイル,ディレクトリを指定してください

.OUTPUTS
結果を表形式で出力します。各項目は DESCRIPTION を確認してください

.LINK
https://msdn.microsoft.com/ja-jp/library/hh215705.aspx
https://technet.microsoft.com/ja-jp/library/dn520871.aspx

.NOTES
TODO: CRUD の if statement 内判別

#>

# params ######################################################################
[CmdletBinding()] 
#to operate option order: -tablelist > -p > -f > -t > -c > -r > parse > format > tables > crud > tree
param (
	[parameter(Mandatory=$true, helpmessage="input ""tsql-string"" or file/directory to parse.")] [alias('s')] [string] $source = $args[0],
	[parameter()] [ValidateSet( 'crud','tables','parse','tree','format' )] [string] $op = "parse",
	[switch] $c = $false,
	[switch] $t = $false,
	[switch] $p = $false,
	[switch] $r = $false,
	[switch] $f = $false,
	[switch] $desc = $false,
	[switch] $tablelist = $false,
	[parameter()] [ValidateSet( 'TSql80Parser','TSql90Parser','TSql100Parser','TSql110Parser','TSql120Parser' )] [string] $version = "TSql110Parser"
)

if ($r) { $op = "tree" }
if ($c) { $op = "crud" }
if ($t) { $op = "tables" }
if ($f) { $op = "format" }
if ($p) { $op = "parse" }
if ($tablelist) { $op = "tables" }

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
			getcrud $stmt.ThenStatement $stmts
			if ($stmt.ElseStatement) { getcrud $stmt.ElseStatement $stmts }
			getcrud $stmt.Predicate $stmts
		}
		"ExistsPredicate" {
			if ($stmt.Subquery.QueryExpression.FromClause) {
				$iftarget = $(gettables $stmt.Subquery.QueryExpression $stmts)
$iftarget
				$stmts.tables
			} 
		}
		default { 
			#$stmt.gettype().name
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
	if ($tablelist) {
		mkdir "tablelist" -ErrorAction SilentlyContinue
		$tables = @{};
		$buffertable | select source, tables | % { $tables[$_.source] += @($_.tables) }
		foreach ($key in $tables.keys) {
			$fn = "tablelist\" + $key.replace("\","_").replace(".sql",".txt")
			$tables[$key] | sort -unique | out-file $fn
		}
		write-host("tablelist of sources are stored in tablelist\")
	} else {
		if (-not $desc) {
			$buffertable | select type, source, tables, query
		} else {
			$buffertable 
		}
	}
	exit; 
}


# crud
$crud = @{};
$buffertable | % {
	$stmts = $_;
	if (-not $crud.contains($stmts.source)) {
		$crud.add($stmts.source, [ordered]@{C = @();R = @();U = @();D = @(); });
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
