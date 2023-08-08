module GhostFunction
open Pulse.Lib.Pervasives
module U8 = FStar.UInt8
module R = Pulse.Lib.Reference
module GR = Pulse.Lib.GhostReference

assume val f (x:int) : GTot int

```pulse
ghost
fn test_gtot (x:GR.ref int)
  requires GR.pts_to x full_perm 0
  ensures GR.pts_to x full_perm (f 0)
{
  open GR;
  let y = f 0;
  (x := y)
}
```

```pulse
fn increment (x:GR.ref int) (#n:erased int)
    requires GR.pts_to x full_perm n
    ensures GR.pts_to x full_perm (n + 1)
{  
   open GR;
   let v = !x;
   (x := (v + 1));
}
```

```pulse
ghost
fn incrementg (x:GR.ref int) (#n:erased int)
    requires GR.pts_to x full_perm n
    ensures GR.pts_to x full_perm (n + 1)
{
   open GR;
   let v = !x;
   (x := (v + 1))
}
```

```pulse
ghost
fn test_gtot_app_f (x:GR.ref int) (y:int)
  requires GR.pts_to x full_perm 0
  ensures GR.pts_to x full_perm y
{
  open GR;
  (x := y)
}
```

```pulse
ghost
fn test_gtot_app (x:GR.ref int)
  requires GR.pts_to x full_perm 0
  ensures GR.pts_to x full_perm (f 0)
{
  test_gtot_app_f x (f 0)
}
```
