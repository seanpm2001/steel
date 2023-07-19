module InferenceParallel
module PM = Pulse.Main
open Steel.ST.Util 
open Steel.ST.Reference
open Steel.FractionalPermission
open FStar.Ghost
open Pulse.Steel.Wrapper

module U32 = FStar.UInt32

(*
```pulse
fn test_assert (r0 r1: ref nat)
               (#p0 #p1:perm)
               (#v0:nat)
    requires 
        pts_to r0 p0 v0 **
        (exists v1. pts_to r1 p1 v1)
    ensures
        pts_to r0 p0 v0 **
        (exists v1. pts_to r1 p1 v1)
{
    //assert_ (pts_to r1 ?p1 ?v1); would be nice to have a version that also binds witnesses
    assert_ (pts_to r0 p0 (v0 + 0));
    ()
}
```

```pulse
fn thread (r: ref nat) (incr: nat) (#v: nat)
    requires pts_to r full_perm v
    ensures pts_to r full_perm (v + incr)
{
    r := v + incr
}
```
*)

```pulse
fn write (r: ref U32.t) (#n: erased U32.t)
  requires 
    (pts_to r full_perm n)
  ensures
    (pts_to r full_perm n)
{
    let x = !r;
    r := x;
    ()
}
```


```pulse
fn test_par (r1 r2 r3 r4:ref U32.t)
            (#n1 #n2 #n3 #n4:erased U32.t)
  requires 
    (pts_to r1 full_perm n1 **
     pts_to r2 full_perm n2 **
     pts_to r3 full_perm n3 **
     pts_to r4 full_perm n4)
  ensures
    (pts_to r1 full_perm 1ul **
     pts_to r2 full_perm 1ul **
     pts_to r3 full_perm 1ul **
     pts_to r4 full_perm 1ul
    )
{
  parallel
    requires (_) and (_)
    ensures  (_) and (_)
  {
     //write r1 #n1 // Goes to C_ST
    r1 := 1ul; // r3 * r4 (r2)
    r3 := 1ul; // r3 * r4 (r1)
    //r3 := 1ul
    // intersection: r3 * r4
    // difference: r1 * r2
  }
  {
     //r1 := 1ul;
     r4 := 2ul;
     r2 := 1ul;
     r4 := 1ul
  };
  ()
}
```

(*
```pulse
fn test_par_2 (r0 r1: ref nat)
               (#v0:nat) (#v1:nat)
    requires 
        pts_to r0 full_perm v0 ** pts_to r1 full_perm v1
    ensures
        pts_to r0 full_perm (v0 + 1) ** pts_to r1 full_perm (v1 + 2)
{
    parallel
        requires (pts_to r0 full_perm v0) and (pts_to r1 full_perm v1)
        ensures (pts_to r0 full_perm 1) and (pts_to r1 full_perm 2)
    {
        //thread r0 1
        r0 := 1;
        ()
    }
    {
        //thread r1 2
        r1 := 2;
        ()
    }
}
```
*)