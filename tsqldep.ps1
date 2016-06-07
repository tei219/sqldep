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
# dev #
select * from a; update b set a=1; delete c; create table d(id int) :
C : ...d
R : ...a
D : ...c
U : ...b


.OUTPUTS
returns results with table format. 
directly access to property, easy to show you result(s).
PS C:\>$(tsqldep.ps1 -r "select * from a;").tree

.LINK
https://msdn.microsoft.com/ja-jp/library/hh215705.aspx

.NOTES
IfStatements のなかのCRUD
複数テーブル利用時のCRUD振り分けdelete update


#>

# params ######################################################################
[CmdletBinding()]
#to operate option order: -p > -f > -t > -c > -r > parse > format > tables > crud > tree
param (
	[parameter(Mandatory=$true, helpmessage="string/file/directory")] [alias('s')] [string] $source = $args[0],
	[parameter()] [ValidateSet( 'crud','tables','parse','tree','format' )] [string] $op = "parse",
	[switch] $c = $false,
	[switch] $t = $false,
	[switch] $p = $false,
	[switch] $r = $false,
	[switch] $f = $false,
	[switch] $desc = $false,
	[parameter()] $version,
	[parameter()] $sizelimit
)

if ($r) { $op = "tree" }
if ($c) { $op = "crud" }
if ($t) { $op = "tables" }
if ($f) { $op = "format" }
if ($p) { $op = "parse" }

$reserved_keyword = @("ADD","ALL","ALTER","AND","ANY","AS","ASC","AUTHORIZATION","BACKUP","BEGIN",
"BETWEEN","BREAK","BROWSE","BULK","BY","CASCADE","CASE","CHECK","CHECKPOINT","CLOSE","CLUSTERED",
"COALESCE","COLLATE","COLUMN","COMMIT","COMPUTE","CONSTRAINT","CONTAINS","CONTAINSTABLE",
"CONTINUE","CONVERT","CREATE","CROSS","CURRENT","CURRENT_DATE","CURRENT_TIME","CURRENT_TIMESTAMP",
"CURRENT_USER","CURSOR","DATABASE","DBCC","DEALLOCATE","DECLARE","DEFAULT","DELETE","DENY","DESC",
"DISK","DISTINCT","DISTRIBUTED","DOUBLE","DROP","DUMP","ELSE","END","ERRLVL","ESCAPE","EXCEPT",
"EXEC","EXECUTE","EXISTS","EXIT","EXTERNAL","FETCH","FILE","FILLFACTOR","FOR","FOREIGN","FREETEXT",
"FREETEXTTABLE","FROM","FULL","FUNCTION","GOTO","GRANT","GROUP","HAVING","HOLDLOCK","IDENTITY",
"IDENTITY_INSERT","IDENTITYCOL","IF","IN","INDEX","INNER","INSERT","INTERSECT","INTO","IS","JOIN",
"KEY","KILL","LEFT","LIKE","LINENO","LOAD","MERGE","NATIONAL","NOCHECK","NONCLUSTERED","NOT","NULL",
"NULLIF","OF","OFF","OFFSETS","ON","OPEN","OPENDATASOURCE","OPENQUERY","OPENROWSET","OPENXML",
"OPTION","OR","ORDER","OUTER","OVER","PERCENT","PIVOT","PLAN","PRECISION","PRIMARY","PRINT","PROC",
"PROCEDURE","PUBLIC","RAISERROR","READ","READTEXT","RECONFIGURE","REFERENCES","REPLICATION","RESTORE",
"RESTRICT","RETURN","REVERT","REVOKE","RIGHT","ROLLBACK","ROWCOUNT","ROWGUIDCOL","RULE","SAVE","SCHEMA",
"SECURITYAUDIT","SELECT","SEMANTICKEYPHRASETABLE","SEMANTICSIMILARITYDETAILSTABLE","SEMANTICSIMILARITYTABLE",
"SESSION_USER","SET","SETUSER","SHUTDOWN","SOME","STATISTICS","SYSTEM_USER","TABLE","TABLESAMPLE",
"TEXTSIZE","THEN","TO","TOP","TRAN","TRANSACTION","TRIGGER","TRUNCATE","TRY_CONVERT","TSEQUAL","UNION",
"UNIQUE","UNPIVOT","UPDATE","UPDATETEXT","USE","USER","VALUES","VARYING","VIEW","WAITFOR","WHEN",
"WHERE","WHILE","WITH","WITHIN GROUP","WRITETEXT")

$reserved_keyword_odbc = @("ABSOLUTE","ACTION","ADA","ADD","ALL","ALLOCATE","ALTER","AND","ANY","ARE",
"AS","ASC","ASSERTION","AT","AUTHORIZATION","AVG","BEGIN","BETWEEN","BIT","BIT_LENGTH","BOTH","BY",
"CASCADE","CASCADED","CASE","CAST","CATALOG","CHAR","CHAR_LENGTH","CHARACTER","CHARACTER_LENGTH",
"CHECK","CLOSE","COALESCE","COLLATE","COLLATION","COLUMN","COMMIT","CONNECT","CONNECTION","CONSTRAINT",
"CONSTRAINTS","CONTINUE","CONVERT","CORRESPONDING","COUNT","CREATE","CROSS","CURRENT","CURRENT_DATE",
"CURRENT_TIME","CURRENT_TIMESTAMP","CURRENT_USER","CURSOR","DATE","DAY","DEALLOCATE","DEC","DECIMAL",
"DECLARE","DEFAULT","DEFERRABLE","DEFERRED","DELETE","DESC","DESCRIBE","DESCRIPTOR","DIAGNOSTICS",
"DISCONNECT","DISTINCT","DOMAIN","DOUBLE","DROP","ELSE","END","END-EXEC","ESCAPE","EXCEPT","EXCEPTION",
"EXEC","EXECUTE","EXISTS","EXTERNAL","EXTRACT","FALSE","FETCH","FIRST","FLOAT","FOR","FOREIGN","FORTRAN",
"FOUND","FROM","FULL","GET","GLOBAL","GO","GOTO","GRANT","GROUP","HAVING","HOUR","IDENTITY","IMMEDIATE",
"IN","INCLUDE","INDEX","INDICATOR","INITIALLY","INNER","INPUT","INSENSITIVE","INSERT","INT","INTEGER",
"INTERSECT","INTERVAL","INTO","IS","ISOLATION","JOIN","KEY","LANGUAGE","LAST","LEADING","LEFT","LEVEL",
"LIKE","LOCAL","LOWER","MATCH","MAX","MIN","MINUTE","MODULE","MONTH","NAMES","NATIONAL","NATURAL","NCHAR",
"NEXT","NO","NONE","NOT","NULL","NULLIF","NUMERIC","OCTET_LENGTH","OF","ON","ONLY","OPEN","OPTION","OR",
"ORDER","OUTER","OUTPUT","OVERLAPS","PAD","PARTIAL","PASCAL","POSITION","PRECISION","PREPARE","PRESERVE",
"PRIMARY","PRIOR","PRIVILEGES","PROCEDURE","PUBLIC","READ","REAL","REFERENCES","RELATIVE","RESTRICT",
"REVOKE","RIGHT","ROLLBACK","ROWS","SCHEMA","SCROLL","SECOND","SECTION","SELECT","SESSION","SESSION_USER",
"SET","SIZE","SMALLINT","SOME","SPACE","SQL","SQLCA","SQLCODE","SQLERROR","SQLSTATE","SQLWARNING","SUBSTRING",
"SUM","SYSTEM_USER","TABLE","TEMPORARY","THEN","TIME","TIMESTAMP","TIMEZONE_HOUR","TIMEZONE_MINUTE","TO",
"TRAILING","TRANSACTION","TRANSLATE","TRANSLATION","TRIM","TRUE","UNION","UNIQUE","UNKNOWN","UPDATE","UPPER",
"USAGE","USER","USING","VALUE","VALUES","VARCHAR","VARYING","VIEW","WHEN","WHENEVER","WHERE","WITH","WORK",
"WRITE","YEAR","ZONE")

$reserved_keyword_feature = @("ABSOLUTE","ACTION","ADMIN","AFTER","AGGREGATE","ALIAS","ALLOCATE","ARE",
"ARRAY","ASENSITIVE","ASSERTION","ASYMMETRIC","AT","ATOMIC","BEFORE","BINARY","BIT","BLOB","BOOLEAN",
"BOTH","BREADTH","CALL","CALLED","CARDINALITY","CASCADED","CAST","CATALOG","CHAR","CHARACTER","CLASS",
"CLOB","COLLATION","COLLECT","COMPLETION","CONDITION","CONNECT","CONNECTION","CONSTRAINTS","CONSTRUCTOR",
"CORR","CORRESPONDING","COVAR_POP","COVAR_SAMP","CUBE","CUME_DIST","CURRENT_CATALOG","CURRENT_DEFAULT_TRANSFORM_GROUP",
"CURRENT_PATH","CURRENT_ROLE","CURRENT_SCHEMA","CURRENT_TRANSFORM_GROUP_FOR_TYPE","CYCLE","DATA","DATE","DAY",
"DEC","DECIMAL","DEFERRABLE","DEFERRED","DEPTH","DEREF","DESCRIBE","DESCRIPTOR","DESTROY","DESTRUCTOR","DETERMINISTIC",
"DIAGNOSTICS","DICTIONARY","DISCONNECT","DOMAIN","DYNAMIC","EACH","ELEMENT","END-EXEC","EQUALS","EVERY","EXCEPTION",
"FALSE","FILTER","FIRST","FLOAT","FOUND","FREE","FULLTEXTTABLE","FUSION","GENERAL","GET","GLOBAL","GO","GROUPING",
"HOLD","HOST","HOUR","IGNORE","IMMEDIATE","INDICATOR","INITIALIZE","INITIALLY","INOUT","INPUT","INT","INTEGER",
"INTERSECTION","INTERVAL","ISOLATION","ITERATE","LANGUAGE","LARGE","LAST","LATERAL","LEADING","LESS","LEVEL","LIKE_REGEX",
"LIMIT","LN","LOCAL","LOCALTIME","LOCALTIMESTAMP","LOCATOR","MAP","MATCH","MEMBER","METHOD","MINUTE","MOD","MODIFIES",
"MODIFY","MODULE","MONTH","MULTISET","NAMES","NATURAL","NCHAR","NCLOB","NEW","NEXT","NO","NONE","NORMALIZE","NUMERIC",
"OBJECT","OCCURRENCES_REGEX","OLD","ONLY","OPERATION","ORDINALITY","OUT","OUTPUT","OVERLAY","PAD","PARAMETER","PARAMETERS",
"PARTIAL","PARTITION","PATH","PERCENT_RANK","PERCENTILE_CONT","PERCENTILE_DISC","POSITION_REGEX","POSTFIX","PREFIX",
"PREORDER","PREPARE","PRESERVE","PRIOR","PRIVILEGES","RANGE","READS","REAL","RECURSIVE","REF","REFERENCING","REGR_AVGX",
"REGR_AVGY","REGR_COUNT","REGR_INTERCEPT","REGR_R2","REGR_SLOPE","REGR_SXX","REGR_SXY","REGR_SYY","RELATIVE",
"RELEASE","RESULT","RETURNS","ROLE","ROLLUP","ROUTINE","ROW","ROWS","SAVEPOINT","SCOPE","SCROLL","SEARCH","SECOND",
"SECTION","SENSITIVE","SEQUENCE","SESSION","SETS","SIMILAR","SIZE","SMALLINT","SPACE","SPECIFIC","SPECIFICTYPE","SQL",
"SQLEXCEPTION","SQLSTATE","SQLWARNING","START","STATE","STATEMENT","STATIC","STDDEV_POP","STDDEV_SAMP","STRUCTURE",
"SUBMULTISET","SUBSTRING_REGEX","SYMMETRIC","SYSTEM","TEMPORARY","TERMINATE","THAN","TIME","TIMESTAMP","TIMEZONE_HOUR",
"TIMEZONE_MINUTE","TRAILING","TRANSLATE_REGEX","TRANSLATION","TREAT","TRUE","UESCAPE","UNDER","UNKNOWN","UNNEST","USAGE",
"USING","VALUE","VAR_POP","VAR_SAMP","VARCHAR","VARIABLE","WHENEVER","WIDTH_BUCKET","WINDOW","WITHIN","WITHOUT","WORK",
"WRITE","XMLAGG","XMLATTRIBUTES","XMLBINARY","XMLCAST","XMLCOMMENT","XMLCONCAT","XMLDOCUMENT","XMLELEMENT","XMLEXISTS",
"XMLFOREST","XMLITERATE","XMLNAMESPACES","XMLPARSE","XMLPI","XMLQUERY","XMLSERIALIZE","XMLTABLE","XMLTEXT","XMLVALIDATE",
"YEAR","ZONE")

$reserved_keywords = ($reserved_keyword, $reserved_keyword_odbc, $reserved_keyword_feature)

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
	param( $stmt, $pad = 1 )
	$stmt | get-member -membertype property | 
		? { $_.name -notin @("StartLine","StartOffset","FragmentLength","StartColumn","FirstTokenIndex","LastTokenIndex","ScriptTokenStream") } | 
			% { 
					if ($stmt.($_.name) -ne $null) {
						if ($_.name -eq "TableReferences") { 
							$stmt.($_.name) | % { gettables $_ }
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
										$stmt.($_.name) | % { ($_.ServerIdentifier.value, $_.DatabaseIdentifier.value, $_.SchemaIdentifier.value, $_.BaseIdentifier.value) -join "." }
									}
								}
								gettables $stmt.($_.name)
							}
						}
					}
				}
}

function showtables {
	param( $stmt, $parent )
	$tabname = $stmt | % { ($_.ServerIdentifier.value, $_.DatabaseIdentifier.value, $_.SchemaIdentifier.value, $_.BaseIdentifier.value) -join "." }
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

# main ########################################################################
# table format
$tf_parse  = @{Expression={$_.type};Label="type";width=8}, @{Expression={$_.source};Label="source";width=40}, @{Expression={$_.parse_error};Label="parse_error";width=60}, @{Expression={$_.fragment};Label="fragment";width=60}
$tf_tree   = @{Expression={$_.type};Label="type";width=8}, @{Expression={$_.source};Label="source";width=40}, @{Expression={$_.tree};Label="tree";width=60}, @{Expression={$_.query};Label="query";width=60}
$tf_tables = @{Expression={$_.type};Label="type";width=8}, @{Expression={$_.source};Label="source";width=40}, @{Expression={$_.tables};Label="tables";width=60}, @{Expression={$_.query};Label="query";width=60}
$tf_crud   = @{Expression={$_.type};Label="type";width=8}, @{Expression={$_.source};Label="source";width=40}, @{Expression={$_.query};Label="query";width=60}, @{Expression={$_.tables};Label="tables";width=60}

# create $parser
$sqldom = [System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.TransactSql.ScriptDom");
if (-not $sqldom ) { ErrorExit; } #$sqldom.gettypes()
$parser = new-object Microsoft.SqlServer.TransactSql.ScriptDom.TSql110Parser($false);

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
	write-host ("[WARN] parsed error. can't continue, exit.") -foregroundcolor red;
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
	$stmts = $_
	if (-not $crud.contains($stmts.source)) {
		$crud.add($stmts.source, @{C = @();R = @();U = @();D = @(); });
	}
	switch ($stmts.stmt.gettype().name) {
		"CreateTableStatement" { $stmts.tables | % { $crud[$stmts.source]["C"] += $_; } }
		"SelectStatement" { $stmts.tables | % { $crud[$stmts.source]["R"] += $_; } }
		"InsertStatement" { $stmts.tables | % { $crud[$stmts.source]["C"] += $_; } }
		"IfStatement" { $stmts.stmt  }
		"UpdateStatement" { $stmts.tables | % { $crud[$stmts.source]["U"] += $_; } }
		"DeleteStatement" { $stmts.tables | % { $crud[$stmts.source]["D"] += $_; } }
		"DropTableStatement" { $stmts.tables | % { $crud[$stmts.source]["D"] += $_; } }
		default { $stmts.stmt.gettype().name }
	}
}

foreach ($key in $crud.Keys) {
	$key+" : "
	foreach ($k in $crud[$key].keys) {
		$k+" : "+($crud[$key][$k] -join ",")
	}
	" "
}

