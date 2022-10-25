[string]$val="";
Get-ChildItem -Recurse components | `
	Where-Object { (!$_.PSIsContainer) -and (!$_.Name.EndsWith(".inf_")) } | `
	Get-FileHash -Algorithm SHA256 | `
	ForEach-Object { $_.Hash.ToLower()+"  "+((Resolve-Path -Relative -Path $_.Path) -Replace "\\","/") } | `
	Sort-Object -CaseSensitive | `
	ForEach-Object { $val+=$_+"`n" }
Set-Content `
	-NoNewline `
	-Path hash.txt `
	-Value $val
