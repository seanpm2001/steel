module Pulse.Checker.Auto.ElimPure
module RT = FStar.Reflection.Typing
module R = FStar.Reflection
module L = FStar.List.Tot
module T = FStar.Tactics
open FStar.List.Tot
open Pulse.Syntax
open Pulse.Checker.Pure
open Pulse.Checker.Common
open Pulse.Typing
module Metatheory = Pulse.Typing.Metatheory
module VP = Pulse.Checker.VPropEquiv
module F = Pulse.Checker.Framing
open Pulse.Reflection.Util
open Pulse.Checker.Auto.Util
    

let elim_pure_head =
    let elim_pure_explicit_lid = mk_steel_wrapper_lid "elim_pure_explicit" in
    tm_fvar (as_fv elim_pure_explicit_lid)

let elim_pure_head_ty = 
    let open Pulse.Steel.Wrapper in
    let open Steel.Effect.Common in
    `(p:prop -> stt_ghost (squash p) emp_inames
                          (pure p)
                          (fun _ -> emp))

let tm_fstar t = Tm_FStar t Range.range_0

let elim_pure_head_typing (g:env)
    : tot_typing g elim_pure_head (tm_fstar elim_pure_head_ty)
    = admit()

let mk_elim_pure (p:term)
  : st_term
  = let t = Tm_STApp { head = elim_pure_head;
                       arg_qual = None;
                       arg = p }
    in
    wr t


let elim_pure_comp (p:host_term) =
    let st : st_comp = {
        u=u_zero;
        res=tm_fstar (T.mk_squash p);
        pre=Tm_Pure (tm_fstar p);
        post=Tm_Emp
    } in
    C_STGhost Tm_EmpInames st
    
let elim_pure_typing (g:env) (p:host_term)
                     (p_prop:tot_typing g (tm_fstar p) (tm_fstar RT.tm_prop))
   : st_typing g (mk_elim_pure (tm_fstar p)) (elim_pure_comp p)
   = admit();
     T_STApp g elim_pure_head (tm_fstar (`(prop))) None (elim_pure_comp p) _ (elim_pure_head_typing g) p_prop

#push-options "--query_stats --fuel 2 --ifuel 2 --split_queries no --z3rlimit_factor 4"
let continuation_elaborator_with_bind (#g:env) (ctxt:term)
  (#c1:comp{stateful_comp c1})
  (#e1:st_term)
  (e1_typing:st_typing g e1 c1)
  (ctxt_pre1_typing:tot_typing g (Tm_Star ctxt (comp_pre c1)) Tm_VProp)
  : T.Tac (x:var { None? (lookup g x) } &
           continuation_elaborator
             g (Tm_Star ctxt (comp_pre c1))
             (extend x (Inl (comp_res c1)) g) (Tm_Star (open_term (comp_post c1) x) ctxt)) =

  let pre1 = comp_pre c1 in
  let res1 = comp_res c1 in
  let post1 = comp_post c1 in
  let ctxt_typing, pre1_typing = star_typing_inversion ctxt_pre1_typing in
  // let p_prop = Metatheory.pure_typing_inversion pure_typing in
  let v_eq = VE_Comm g ctxt pre1 in
  let framing_token : F.frame_for_req_in_ctxt g (Tm_Star ctxt pre1) pre1 = 
    (| ctxt, ctxt_typing, VE_Comm g pre1 ctxt  |)
  in
  let (| c1, e1_typing |) =
    Pulse.Checker.Framing.apply_frame ctxt_pre1_typing e1_typing framing_token in
  let (| u_of_1, pre_typing, _, _ |) =
    Metatheory.(st_comp_typing_inversion (comp_typing_inversion (st_typing_correctness e1_typing))) in
  let x = fresh g in
  let b = Inl res1 in
  let g' = extend x b g in
  
  let post1_opened = open_term_nv post1 (v_as_nv x) in
  let k : continuation_elaborator g (Tm_Star ctxt pre1) g' (Tm_Star post1_opened ctxt) =
    fun post_hint res ->
    let (| e2, c2, e2_typing |) = res in
    if not (stateful_comp c2) // || None? post_hint
    then T.fail "Unexpected non-stateful comp in continuation elaborate"
    else (
      let e2_typing : st_typing g' e2 c2 = e2_typing in
      let e2_closed = close_st_term e2 x in
      assume (open_st_term e2_closed x == e2);
      assert (comp_pre c1 == (Tm_Star ctxt pre1));
      assert (comp_post c1 == Tm_Star post1 ctxt);
      assert (comp_pre c2 == Tm_Star post1_opened ctxt);
      assert (open_term (comp_post c1) x == Tm_Star post1_opened (open_term ctxt x));
      // ctxt is well-typed, hence ln
      assume (open_term ctxt x == ctxt);
      assert (open_term (comp_post c1) x == comp_pre c2);
      // e2 is well-typed in g, so its fvs should be a subset of g
      assume (~ (x `Set.mem` freevars_st e2));
      if x `Set.mem` freevars (comp_post c2)
      then T.fail "Impossible"
      else (
        let t_typing, post_typing =
          Pulse.Checker.Bind.bind_res_and_post_typing g (st_comp_of_comp c2) x post_hint in
        let (| e, c, e_typing |) =
          Pulse.Checker.Bind.mk_bind
            g (Tm_Star ctxt pre1) 
            e1 e2_closed c1 c2 (v_as_nv x) e1_typing
            u_of_1 
            e2_typing
            t_typing
            post_typing
        in
        (| e, c, e_typing |)
      )
    )

  in
  (| x, k |)

let elim_one_pure (#g:env) (ctxt:term) (p:term)
                  (ctxt_p_typing:tot_typing g (Tm_Star ctxt (Tm_Pure p)) Tm_VProp)
  : T.Tac (g':env { env_extends g' g } &
           tot_typing g' ctxt Tm_VProp &
           continuation_elaborator g (Tm_Star ctxt (Tm_Pure p)) g' ctxt) =
  
  let ctxt_typing, pure_typing = star_typing_inversion ctxt_p_typing in
  let p_prop = Metatheory.pure_typing_inversion pure_typing in

  match p with
  | Tm_FStar pp _ ->
    let e1 = mk_elim_pure (tm_fstar pp) in
    let c1 = elim_pure_comp pp in
    let e1_typing = elim_pure_typing g pp p_prop in
    let (| x, k |) = continuation_elaborator_with_bind ctxt e1_typing ctxt_p_typing in
    let g' = extend x (Inl (comp_res c1)) g in
    let ctxt_g'_typing : tot_typing g' ctxt Tm_VProp =
      Metatheory.tot_typing_weakening x (Inl (comp_res c1)) ctxt_typing in
    let k
      : continuation_elaborator
          g (Tm_Star ctxt (Tm_Pure p))
          g' (Tm_Star Tm_Emp ctxt) =
      k in
    let k
      : continuation_elaborator
          g (Tm_Star ctxt (Tm_Pure p))
          g' ctxt =
      k_elab_equiv k (VE_Refl _ _) (VE_Unit _ ctxt) in
    Pulse.Checker.Common.extends_extends_env g x (Inl (comp_res c1));
    (| g', ctxt_g'_typing, k |)

  | _ -> T.fail "unexpected pure term"

let rec elim_pure_right (#g:env) (#ctxt:term) (ctxt_typing:tot_typing g ctxt Tm_VProp)
   : T.Tac (g':env { env_extends g' g } &
            ctxt':term &
            tot_typing g' ctxt' Tm_VProp &
            continuation_elaborator g ctxt g' ctxt')
   = match ctxt with
     | Tm_Star ctxt' (Tm_Pure p) ->
       let (| g', ctxt_typing', k |) = elim_one_pure ctxt' p ctxt_typing in
       let (| g'', ctxt'', ctxt_typing'', k' |) = elim_pure_right ctxt_typing' in
       (| g'', ctxt'', ctxt_typing'', k_elab_trans k k' |)
     | _ ->
        extends_env_refl g;
       (| g, ctxt, ctxt_typing, k_elab_unit _ _ |)

module F = Pulse.Checker.Framing
open Pulse.Checker.VPropEquiv

let rec canon_right_aux (g:env) (vps:list vprop) (f:vprop -> bool)
  : vps' : list vprop &
    fvps : list vprop { forall (v:vprop). List.Tot.memP v fvps ==> f v } &
    vprop_equiv g (list_as_vprop vps) (list_as_vprop (vps' @ fvps)) =

  match vps with
  | [] -> (| [], [], VE_Refl _ _ |)
  | hd::rest ->
    if f hd
    then begin
      let (| vps', fvps, v_eq |) = canon_right_aux g rest f in
      let v_eq
        : vprop_equiv g (list_as_vprop vps)
                        (list_as_vprop (hd :: (vps' @ fvps)))
        = list_as_vprop_ctx g [hd] _ rest (vps' @ fvps) (VE_Refl _ _) v_eq    
      in  
      let v_eq
        : vprop_equiv g (list_as_vprop vps)
                        (list_as_vprop ((vps'@[hd]) @ fvps))
        = VE_Trans _ _ _ _ v_eq (VE_Sym _ _ _ (vprop_equiv_swap_equiv _ _ _ hd _ (VE_Refl _ _)))
      in
      let v_eq 
        :  vprop_equiv g (list_as_vprop vps)
                         (list_as_vprop (vps'@(hd::fvps)))
        = VE_Trans _ _ _ _ v_eq (VE_Sym _ _ _ (list_as_vprop_assoc _ _ _ _)) in
      (| vps', hd :: fvps, v_eq |)
    end
    else begin
      let (| vps', pures, v_eq |) = canon_right_aux g rest f in
      let v_eq = list_as_vprop_ctx g [hd] _ _ _ (VE_Refl _ _) v_eq in
      (| hd::vps', pures, v_eq |)
    end

let canon_right (#g:env) (#ctxt:term) (ctxt_typing:tot_typing g ctxt Tm_VProp)
  (f:vprop -> bool)
  : (ctxt':term &
     tot_typing g ctxt' Tm_VProp &
     continuation_elaborator g ctxt g ctxt')
  = let ctxt' = canon_vprop ctxt in
    let (| vps', pures, veq |) = canon_right_aux g (vprop_as_list ctxt) f in
    let veq : vprop_equiv g ctxt (list_as_vprop (vps'@pures)) =
        VE_Trans _ _ _ _ (vprop_list_equiv g ctxt) veq
    in
    (| _, VP.vprop_equiv_typing_fwd ctxt_typing veq, k_elab_equiv (k_elab_unit _ _) (VE_Refl _ _) veq |)


let canon_pure_right (#g:env) (#ctxt:term) (ctxt_typing:tot_typing g ctxt Tm_VProp)
  : (ctxt':term &
     tot_typing g ctxt' Tm_VProp &
     continuation_elaborator g ctxt g ctxt')
  = canon_right ctxt_typing Tm_Pure?

let elim_pure (#g:env) (#ctxt:term) (ctxt_typing:tot_typing g ctxt Tm_VProp)
   : T.Tac (g':env { env_extends g' g } &
            ctxt':term &
            tot_typing g' ctxt' Tm_VProp &
            continuation_elaborator g ctxt g' ctxt')
   = let (| ctxt', ctxt'_typing, k |) = canon_pure_right ctxt_typing in
     let (| g', ctxt'', ctxt''_typing, k' |) = elim_pure_right ctxt'_typing in
     extends_env_refl g;
     (| g', ctxt'', ctxt''_typing, k_elab_trans k k' |)
