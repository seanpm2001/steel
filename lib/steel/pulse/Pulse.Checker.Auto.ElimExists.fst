module Pulse.Checker.Auto.ElimExists
open Pulse.Syntax
open Pulse.Checker.Common
open Pulse.Typing

module T = FStar.Tactics

open Pulse.Checker.Auto.Util

let should_elim_exists (v:vprop) =
  match v with
  | Tm_ExistsSL _ _ _ s -> T.unseal s
  | _ -> false

let mk_elim_exists_tm (p:vprop) : st_term = wr (Tm_ElimExists {p})

let mk (#g:env) (#v:vprop) (v_typing:tot_typing g v Tm_VProp)
  : T.Tac (option (t:st_term &
                   c:comp { stateful_comp c /\ comp_pre c == v } &
                   st_typing g t c)) =

  match v with
  | Tm_ExistsSL u t p s ->
    if T.unseal s then
      let tm = mk_elim_exists_tm p in
      let x = fresh g in
      let c = Pulse.Typing.comp_elim_exists u t p x in
      let tm_typing : st_typing g tm c = magic () in
      Some (| tm, c, tm_typing |)
    else None
  | _ -> None

let elim_exists (#g:env) (#ctxt:term) (ctxt_typing:tot_typing g ctxt Tm_VProp)
  : T.Tac (g':env { env_extends g' g } &
           ctxt':term &
           tot_typing g' ctxt' Tm_VProp &
           continuation_elaborator g ctxt g' ctxt') =

  add_elims should_elim_exists mk ctxt_typing