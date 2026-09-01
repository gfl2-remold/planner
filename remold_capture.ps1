# GFL2 remolding memory capture (standalone, public build).
# Reads the game heap READ-ONLY and writes owned remolding items to Desktop\gf2_remold.csv
# in the logger CSV format. Same validated logic as the desktop Ctrl+R path
# (exactly 1 main code at Lv3/gamma per item, median occurrence = base, round(occ/base) = owned count).
# Run this as administrator; open the REMOLDING STORAGE screen in game first.
# Saved as UTF-8 WITH BOM so PowerShell 5.1 parses the Korean strings correctly.
# Console output uses the console's default encoding (CP949 on Korean Windows) so Hangul renders.
$ErrorActionPreference = 'Stop'

# --- self-elevate to administrator ---
$pr = New-Object System.Security.Principal.WindowsPrincipal([System.Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $pr.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)) {
  Write-Host '관리자 권한을 요청합니다 (UAC 창이 뜨면 [예]를 누르세요)...'
  try {
    Start-Process powershell -Verb RunAs -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-File',("`"" + $PSCommandPath + "`"")
  } catch { Write-Host '관리자 권한이 필요합니다. 취소되었습니다.'; Start-Sleep -Seconds 3 }
  return
}

Write-Host 'GFL2 리몰딩 메모리 캡처'
Write-Host '게임을 실행하고 [리몰딩 창고] 화면을 열어둔 상태에서 진행하세요.'
Write-Host ''

# --- embedded code table ---
$CODES  = @( 1400101, 1400102, 1400103, 1400201, 1400202, 1400203, 1400301, 1400302, 1400303, 1400401, 1400402, 1400403, 1200101, 1200102, 1200103, 1200201, 1200202, 1200203, 1200301, 1200302, 1200303, 1200401, 1200402, 1200403, 1100101, 1100102, 1100103, 1100201, 1100202, 1100203, 1100301, 1100302, 1100303, 1100401, 1100402, 1100403, 1300101, 1300102, 1300103, 1300201, 1300202, 1300203, 1300301, 1300302, 1300303, 1300401, 1300402, 1300403, 2400801, 2400802, 2400803, 2400701, 2400702, 2400703, 2400401, 2400402, 2400403, 2400101, 2400102, 2400103, 2400201, 2400202, 2400203, 2400501, 2400502, 2400503, 2400301, 2400302, 2400303, 2400601, 2400602, 2400603, 2401101, 2401102, 2401103, 2401001, 2401002, 2401003, 2400901, 2400902, 2200801, 2200802, 2200803, 2200701, 2200702, 2200703, 2200401, 2200402, 2200403, 2200101, 2200102, 2200103, 2200201, 2200202, 2200203, 2200501, 2200502, 2200503, 2200301, 2200302, 2200303, 2200601, 2200602, 2200603, 2201001, 2201002, 2201003, 2201101, 2201102, 2201103, 2200901, 2200902, 2100801, 2100802, 2100803, 2100701, 2100702, 2100703, 2100401, 2100402, 2100403, 2100101, 2100102, 2100103, 2100201, 2100202, 2100203, 2100501, 2100502, 2100503, 2100301, 2100302, 2100303, 2100601, 2100602, 2100603, 2101001, 2101002, 2101003, 2101101, 2101102, 2101103, 2100901, 2100902, 2100903, 2300701, 2300702, 2300703, 2300801, 2300802, 2300803, 2300401, 2300402, 2300403, 2300101, 2300102, 2300103, 2300201, 2300202, 2300203, 2300501, 2300502, 2300503, 2300301, 2300302, 2300303, 2300601, 2300602, 2300603, 2301001, 2301002, 2301003, 2301101, 2301102, 2301103, 2300901, 2300902 )
$HEX    = @( 'a5 ba 55', 'a6 ba 55', 'a7 ba 55', '89 bb 55', '8a bb 55', '8b bb 55', 'ed bb 55', 'ee bb 55', 'ef bb 55', 'd1 bc 55', 'd2 bc 55', 'd3 bc 55', 'e5 9f 49', 'e6 9f 49', 'e7 9f 49', 'c9 a0 49', 'ca a0 49', 'cb a0 49', 'ad a1 49', 'ae a1 49', 'af a1 49', '91 a2 49', '92 a2 49', '93 a2 49', 'c5 92 43', 'c6 92 43', 'c7 92 43', 'a9 93 43', 'aa 93 43', 'ab 93 43', '8d 94 43', '8e 94 43', '8f 94 43', 'f1 94 43', 'f2 94 43', 'f3 94 43', '85 ad 4f', '86 ad 4f', '87 ad 4f', 'e9 ad 4f', 'ea ad 4f', 'eb ad 4f', 'cd ae 4f', 'ce ae 4f', 'cf ae 4f', 'b1 af 4f', 'b2 af 4f', 'b3 af 4f', 'a1 c4 92', 'a2 c4 92', 'a3 c4 92', 'bd c3 92', 'be c3 92', 'bf c3 92', '91 c1 92', '92 c1 92', '93 c1 92', 'e5 be 92', 'e6 be 92', 'e7 be 92', 'c9 bf 92', 'ca bf 92', 'cb bf 92', 'f5 c1 92', 'f6 c1 92', 'f7 c1 92', 'ad c0 92', 'ae c0 92', 'af c0 92', 'd9 c2 92', 'da c2 92', 'db c2 92', 'cd c6 92', 'ce c6 92', 'cf c6 92', 'e9 c5 92', 'ea c5 92', 'eb c5 92', '85 c5 92', '86 c5 92', 'e1 a9 86', 'e2 a9 86', 'e3 a9 86', 'fd a8 86', 'fe a8 86', 'ff a8 86', 'd1 a6 86', 'd2 a6 86', 'd3 a6 86', 'a5 a4 86', 'a6 a4 86', 'a7 a4 86', '89 a5 86', '8a a5 86', '8b a5 86', 'b5 a7 86', 'b6 a7 86', 'b7 a7 86', 'ed a5 86', 'ee a5 86', 'ef a5 86', '99 a8 86', '9a a8 86', '9b a8 86', 'a9 ab 86', 'aa ab 86', 'ab ab 86', '8d ac 86', '8e ac 86', '8f ac 86', 'c5 aa 86', 'c6 aa 86', 'c1 9c 80', 'c2 9c 80', 'c3 9c 80', 'dd 9b 80', 'de 9b 80', 'df 9b 80', 'b1 99 80', 'b2 99 80', 'b3 99 80', '85 97 80', '86 97 80', '87 97 80', 'e9 97 80', 'ea 97 80', 'eb 97 80', '95 9a 80', '96 9a 80', '97 9a 80', 'cd 98 80', 'ce 98 80', 'cf 98 80', 'f9 9a 80', 'fa 9a 80', 'fb 9a 80', '89 9e 80', '8a 9e 80', '8b 9e 80', 'ed 9e 80', 'ee 9e 80', 'ef 9e 80', 'a5 9d 80', 'a6 9d 80', 'a7 9d 80', '9d b6 8c', '9e b6 8c', '9f b6 8c', '81 b7 8c', '82 b7 8c', '83 b7 8c', 'f1 b3 8c', 'f2 b3 8c', 'f3 b3 8c', 'c5 b1 8c', 'c6 b1 8c', 'c7 b1 8c', 'a9 b2 8c', 'aa b2 8c', 'ab b2 8c', 'd5 b4 8c', 'd6 b4 8c', 'd7 b4 8c', '8d b3 8c', '8e b3 8c', '8f b3 8c', 'b9 b5 8c', 'ba b5 8c', 'bb b5 8c', 'c9 b8 8c', 'ca b8 8c', 'cb b8 8c', 'ad b9 8c', 'ae b9 8c', 'af b9 8c', 'e5 b7 8c', 'e6 b7 8c' )
$ISMAIN = @( 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 )
$LV     = @( 1, 2, 3, 1, 2, 3, 1, 2, 3, 1, 2, 3, 1, 2, 3, 1, 2, 3, 1, 2, 3, 1, 2, 3, 1, 2, 3, 1, 2, 3, 1, 2, 3, 1, 2, 3, 1, 2, 3, 1, 2, 3, 1, 2, 3, 1, 2, 3, 1, 2, 3, 1, 2, 3, 1, 2, 3, 1, 2, 3, 1, 2, 3, 1, 2, 3, 1, 2, 3, 1, 2, 3, 1, 2, 3, 1, 2, 3, 1, 2, 1, 2, 3, 1, 2, 3, 1, 2, 3, 1, 2, 3, 1, 2, 3, 1, 2, 3, 1, 2, 3, 1, 2, 3, 1, 2, 3, 1, 2, 3, 1, 2, 1, 2, 3, 1, 2, 3, 1, 2, 3, 1, 2, 3, 1, 2, 3, 1, 2, 3, 1, 2, 3, 1, 2, 3, 1, 2, 3, 1, 2, 3, 1, 2, 3, 1, 2, 3, 1, 2, 3, 1, 2, 3, 1, 2, 3, 1, 2, 3, 1, 2, 3, 1, 2, 3, 1, 2, 3, 1, 2, 3, 1, 2, 3, 1, 2 )

Add-Type @'
using System;using System.Runtime.InteropServices;using System.Collections.Generic;
public class Mem{
 [DllImport("kernel32.dll",SetLastError=true)] public static extern IntPtr OpenProcess(int a,bool b,int p);
 [DllImport("kernel32.dll")] public static extern bool ReadProcessMemory(IntPtr h,IntPtr a,byte[] b,long s,out int r);
 [DllImport("kernel32.dll")] public static extern int VirtualQueryEx(IntPtr h,IntPtr a,out MEMINFO m,int l);
 [DllImport("kernel32.dll")] public static extern bool CloseHandle(IntPtr h);
 [StructLayout(LayoutKind.Sequential)] public struct MEMINFO{public IntPtr BaseAddress;public IntPtr AllocationBase;public int AllocationProtect;public IntPtr RegionSize;public int State;public int Protect;public int Type;}
 public static List<string> Runs(byte[] buf,int len,HashSet<int> set){
  var runs=new List<string>(); int n=len-4,i=0;
  while(i<=n){ int v=buf[i]|(buf[i+1]<<8)|(buf[i+2]<<16)|(buf[i+3]<<24);
   if(set.Contains(v)){ var r=new List<int>(); int j=i;
    while(j<=n){ int w=buf[j]|(buf[j+1]<<8)|(buf[j+2]<<16)|(buf[j+3]<<24); if(set.Contains(w)){ r.Add(w); j+=4; } else break; }
    if(r.Count>=2&&r.Count<=3) runs.Add(string.Join(",",r)); i=j;
   } else i++; }
  return runs;
 }
}
'@

$p = Get-Process GF2_Exilium -ErrorAction SilentlyContinue
if(-not $p){ Write-Host '오류: 게임(GF2_Exilium)이 실행 중이 아닙니다.'; Read-Host '엔터를 누르면 닫힙니다'; return }
$h = [Mem]::OpenProcess(0x410,$false,$p.Id); if($h -eq [IntPtr]::Zero){ $h=[Mem]::OpenProcess(0x1010,$false,$p.Id) }
if($h -eq [IntPtr]::Zero){ Write-Host '오류: 메모리 접근 실패 (관리자 권한이 필요합니다).'; Read-Host '엔터를 누르면 닫힙니다'; return }

$set=New-Object 'System.Collections.Generic.HashSet[int]'
$hexOf=@{}; $ismain=@{}; $lv=@{}
for($k=0;$k -lt $CODES.Count;$k++){ $iv=[int]$CODES[$k]; [void]$set.Add($iv); $hexOf[$iv]=$HEX[$k]; $ismain[$iv]=[int]$ISMAIN[$k]; $lv[$iv]=[int]$LV[$k] }

Write-Host '메모리 스캔 중... 게임 메모리 크기에 따라 수십 초 걸릴 수 있습니다. 창을 닫지 마세요.'
Write-Host -NoNewline '  '
$count=@{}; $repr=@{}; $addr=[Int64]0; $max=[Int64]0x7FFFFFFFFFFF; $regions=0; $seen=0
while($addr -lt $max){
 $mi=New-Object Mem+MEMINFO
 if([Mem]::VirtualQueryEx($h,[IntPtr]$addr,[ref]$mi,[Runtime.InteropServices.Marshal]::SizeOf($mi)) -eq 0){ break }
 $sz=[Int64]$mi.RegionSize; $prot=$mi.Protect
 if($mi.State -eq 0x1000 -and ($prot -eq 0x04 -or $prot -eq 0x40) -and $mi.Type -eq 0x20000 -and $sz -gt 0 -and $sz -lt 96MB){
  $buf=New-Object byte[] $sz; $r=0
  if([Mem]::ReadProcessMemory($h,$mi.BaseAddress,$buf,$sz,[ref]$r) -and $r -gt 0){
   $regions++; if($regions % 40 -eq 0){ Write-Host -NoNewline '.' }
   foreach($run in [Mem]::Runs($buf,$r,$set)){
    $ints=$run -split ',' | ForEach-Object { [int]$_ }
    $mains=@($ints | Where-Object { $ismain[$_] -eq 1 })
    if($mains.Count -ne 1){ continue }
    $mc=$mains[0]; if($lv[$mc] -lt 3){ continue }
    $subs=@($ints | Where-Object { $_ -ne $mc } | Sort-Object)
    $key = "$mc|" + ($subs -join ',')
    if($count.ContainsKey($key)){ $count[$key]++ } else { $count[$key]=1; $repr[$key]=@($mc)+$subs }
   }
  }
 }
 # advance; guard against a zero/negative region size so we never loop forever
 if($sz -le 0){ $sz=0x1000 }
 $addr=[Int64]$mi.BaseAddress + $sz
}
[Mem]::CloseHandle($h) | Out-Null
Write-Host ''

if($count.Count -eq 0){ Write-Host '오류: 리몰딩 아이템 미검출 — 게임에서 [리몰딩 창고]를 열고 다시 실행하세요.'; Read-Host '엔터를 누르면 닫힙니다'; return }
$occ=@($count.Values | Sort-Object); $base=$occ[[int]($occ.Count/2)]; if($base -lt 1){ $base=1 }; $half=$base*0.5

$sb=New-Object System.Text.StringBuilder; [void]$sb.AppendLine('uid,stat1,stat2,stat3')
$idx=0; $rowN=0; $items=0; $amb=@()
foreach($kk in $count.Keys){
 if($count[$kk] -lt $half){ continue }
 $arr=$repr[$kk]
 $s1=$hexOf[[int]$arr[0]]; $s2= if($arr.Count -ge 2){$hexOf[[int]$arr[1]]}else{''}; $s3= if($arr.Count -ge 3){$hexOf[[int]$arr[2]]}else{''}
 $ratio=$count[$kk]/[double]$base; $frac=$ratio-[Math]::Floor($ratio)
 $owned=[int][Math]::Round($ratio); if($owned -lt 1){ $owned=1 }
 if($frac -ge 0.45 -and $frac -le 0.55 -and $ratio -ge 1.0){ $amb += ('code {0} (occ {1}/base {2} -> {3}?)' -f $arr[0],$count[$kk],$base,$owned) }
 $items++
 for($n=0;$n -lt $owned;$n++){ $idx++; $rowN++; [void]$sb.AppendLine(('M{0},{1},{2},{3}' -f $idx,$s1,$s2,$s3)) }
}
$desktop=[Environment]::GetFolderPath('Desktop')
$outCsv=Join-Path $desktop 'gf2_remold.csv'
[System.IO.File]::WriteAllText($outCsv, $sb.ToString(), (New-Object System.Text.UTF8Encoding($true)))
Write-Host ''
Write-Host ("완료: 리몰딩 {0}종 / {1}행 추출 (base={2}, 영역 {3}개)" -f $items,$rowN,$base,$regions)
Write-Host ("저장됨 -> {0}" -f $outCsv)
if($amb.Count -gt 0){ Write-Host ("경고: 개수 불확실 {0}건 (게임에서 직접 확인 권장):" -f $amb.Count); $amb | ForEach-Object { Write-Host ("   "+$_) } }
Write-Host ''
Write-Host '이제 계산기의 [가져오기]로 바탕화면의 gf2_remold.csv 파일을 올리세요.'
Read-Host '엔터를 누르면 닫힙니다'
