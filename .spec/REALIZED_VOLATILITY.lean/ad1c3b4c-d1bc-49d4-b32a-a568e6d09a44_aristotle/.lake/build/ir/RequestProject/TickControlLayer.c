// Lean compiler output
// Module: RequestProject.TickControlLayer
// Imports: public import Init public import Mathlib public import RequestProject.TickDualMapping
#include <lean/lean.h>
#if defined(__clang__)
#pragma clang diagnostic ignored "-Wunused-parameter"
#pragma clang diagnostic ignored "-Wunused-label"
#elif defined(__GNUC__) && !defined(__CLANG__)
#pragma GCC diagnostic ignored "-Wunused-parameter"
#pragma GCC diagnostic ignored "-Wunused-label"
#pragma GCC diagnostic ignored "-Wunused-but-set-variable"
#endif
#ifdef __cplusplus
extern "C" {
#endif
LEAN_EXPORT lean_object* lp_RequestProject_TickControlLayer_tickRec___boxed(lean_object*, lean_object*, lean_object*, lean_object*, lean_object*, lean_object*);
lean_object* lp_mathlib_Real_definition___lam__0_00___x40_Mathlib_Data_Real_Basic_4214226450____hygCtx___hyg_8_(lean_object*, lean_object*, lean_object*);
lean_object* lp_mathlib_Real_definition___lam__0_00___x40_Mathlib_Data_Real_Basic_1138242547____hygCtx___hyg_8_(lean_object*, lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_RequestProject_TickControlLayer_tickRec(lean_object*, lean_object*, lean_object*, lean_object*, lean_object*, lean_object*);
uint8_t lean_nat_dec_eq(lean_object*, lean_object*);
lean_object* lean_nat_sub(lean_object*, lean_object*);
lean_object* lean_nat_add(lean_object*, lean_object*);
LEAN_EXPORT lean_object* lp_RequestProject_TickControlLayer_tickRec(lean_object* x_1, lean_object* x_2, lean_object* x_3, lean_object* x_4, lean_object* x_5, lean_object* x_6) {
_start:
{
lean_object* x_7; uint8_t x_8; 
x_7 = lean_unsigned_to_nat(0u);
x_8 = lean_nat_dec_eq(x_6, x_7);
if (x_8 == 1)
{
lean_dec(x_5);
lean_dec(x_3);
lean_dec(x_2);
lean_dec(x_1);
lean_inc(x_4);
return x_4;
}
else
{
lean_object* x_9; lean_object* x_10; lean_object* x_11; lean_object* x_12; lean_object* x_13; lean_object* x_14; lean_object* x_15; lean_object* x_16; lean_object* x_17; lean_object* x_18; lean_object* x_19; 
x_9 = lean_unsigned_to_nat(1u);
x_10 = lean_nat_sub(x_6, x_9);
lean_inc(x_5);
lean_inc(x_3);
lean_inc(x_2);
lean_inc(x_1);
x_11 = lp_RequestProject_TickControlLayer_tickRec(x_1, x_2, x_3, x_4, x_5, x_10);
lean_inc(x_11);
x_12 = lean_apply_1(x_1, x_11);
x_13 = lean_alloc_closure((void*)(lp_mathlib_Real_definition___lam__0_00___x40_Mathlib_Data_Real_Basic_4214226450____hygCtx___hyg_8_), 3, 2);
lean_closure_set(x_13, 0, x_5);
lean_closure_set(x_13, 1, x_12);
lean_inc(x_11);
x_14 = lean_alloc_closure((void*)(lp_mathlib_Real_definition___lam__0_00___x40_Mathlib_Data_Real_Basic_1138242547____hygCtx___hyg_8_), 3, 2);
lean_closure_set(x_14, 0, x_11);
lean_closure_set(x_14, 1, x_13);
x_15 = lean_apply_1(x_2, x_11);
x_16 = lean_nat_add(x_10, x_9);
lean_dec(x_10);
x_17 = lean_apply_1(x_3, x_16);
x_18 = lean_alloc_closure((void*)(lp_mathlib_Real_definition___lam__0_00___x40_Mathlib_Data_Real_Basic_4214226450____hygCtx___hyg_8_), 3, 2);
lean_closure_set(x_18, 0, x_15);
lean_closure_set(x_18, 1, x_17);
x_19 = lean_alloc_closure((void*)(lp_mathlib_Real_definition___lam__0_00___x40_Mathlib_Data_Real_Basic_1138242547____hygCtx___hyg_8_), 3, 2);
lean_closure_set(x_19, 0, x_14);
lean_closure_set(x_19, 1, x_18);
return x_19;
}
}
}
LEAN_EXPORT lean_object* lp_RequestProject_TickControlLayer_tickRec___boxed(lean_object* x_1, lean_object* x_2, lean_object* x_3, lean_object* x_4, lean_object* x_5, lean_object* x_6) {
_start:
{
lean_object* x_7; 
x_7 = lp_RequestProject_TickControlLayer_tickRec(x_1, x_2, x_3, x_4, x_5, x_6);
lean_dec(x_6);
lean_dec(x_4);
return x_7;
}
}
lean_object* initialize_Init(uint8_t builtin);
lean_object* initialize_mathlib_Mathlib(uint8_t builtin);
lean_object* initialize_RequestProject_RequestProject_TickDualMapping(uint8_t builtin);
static bool _G_initialized = false;
LEAN_EXPORT lean_object* initialize_RequestProject_RequestProject_TickControlLayer(uint8_t builtin) {
lean_object * res;
if (_G_initialized) return lean_io_result_mk_ok(lean_box(0));
_G_initialized = true;
res = initialize_Init(builtin);
if (lean_io_result_is_error(res)) return res;
lean_dec_ref(res);
res = initialize_mathlib_Mathlib(builtin);
if (lean_io_result_is_error(res)) return res;
lean_dec_ref(res);
res = initialize_RequestProject_RequestProject_TickDualMapping(builtin);
if (lean_io_result_is_error(res)) return res;
lean_dec_ref(res);
return lean_io_result_mk_ok(lean_box(0));
}
#ifdef __cplusplus
}
#endif
