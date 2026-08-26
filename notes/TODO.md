


% ============================================================
% 1) (\varphi^\sigma, \pi^\sigma)
% ============================================================

\[
\boxed{
\text{TODO:}\qquad
1)\;(\varphi^\sigma,\pi^\sigma)
}
\]

From Making, what other properties, theprems we can derive

\[
\begin{aligned}
\varphi_{(\chi_{X/M},\epsilon_{X/M})}
\left(
Q_X^L + \Delta Q_X,\,
Q_M^L + \Delta Q_M
\right)
=
\varphi_{(\chi_{X/M},\epsilon_{X/M})}
\left(
Q_X^L,Q_M^L
\right)
&=
\overline{L}_{(\chi_{X/M},\epsilon_{X/M})}.
\end{aligned}
\]

Considering the result:

\[
\begin{aligned}
\overline{L}_{(\chi_{X/M},\epsilon_{X/M})}
&\longrightarrow
\overline{L}_{(1/2,0)},
\\[4pt]
\varphi_{(\chi,\epsilon)}
&\longrightarrow
\varphi_{(1/2,0)}.
\end{aligned}
\]

From

\[
\Theta_\nu
\longrightarrow
L_\nu
=
\Delta Q_\nu
\qquad\Longrightarrow\qquad
\Delta Q_\nu
=
\Delta Q_\nu(\sigma_K).
\]

Therefore we define,

\[
\begin{aligned}
\varphi^{\sigma}
\left(
Q_X^{L_{\sigma}},
Q_M^{L_{\sigma}}
\right)
&=
Q_M^{L_{\sigma}}
-
\left(
L_{\sigma}-\frac{1}{2}Q_X^{L_\sigma}
\right)^2.
\end{aligned}
\]

Hence the remaining mapping/problem is

\[
\boxed{
\varphi^\nu
\longrightarrow
\varphi_{(\chi,\epsilon)}.
}
\] ?


% ============================================================
% 2) Bid / Ask fee prices
% ============================================================

\[
\boxed{
2)\;
\left(
P_\varphi^{(\mathrm{bid})},
P_\varphi^{(\mathrm{ask})}
\right)
}
\]

Introducing \( (\phi , \otimes_\phi)\), we have

\[
\begin{aligned}
\varphi_{(\chi,\epsilon)}
\left(
Q_X^L+\phi\,\Delta Q_X,\,
Q_M^L+\phi\,\Delta Q_M
\right)
=
\varphi_{(\chi,\epsilon)}
\left(
Q_X^L,Q_M^L
\right).
\end{aligned}
\]

Recall:

\[
\begin{aligned}
P_\varphi
&=
\frac{
\partial \varphi/\partial \Delta Q_X
}{
\partial \varphi/\partial \Delta Q_M
}
=
\frac{1}{p_{(\eta,\Delta_i)} (i) \cdot p_{(\eta,\Delta_i)} (i + \Delta_i)}.
\end{aligned}
\]

Define

\[
\boxed{
P_\varphi^{(\mathrm{bid})}
\equiv
\frac{P_\varphi}{\phi},
\qquad
P_\varphi^{(\mathrm{ask})}
\equiv
\phi P_\varphi.
}
\]

Then

\[
\begin{aligned}
\frac{
P_\varphi^{(\mathrm{ask})}
-
P_\varphi^{(\mathrm{bid})}
}{
P_\varphi
}
&\equiv
\frac{(\phi-1)(\phi+1)}{\phi}.
\end{aligned}
\]

Therefore,

\[
\begin{aligned}
\frac{\partial \pi^\phi}{\partial \Delta Q_X}
&=
\frac{1-\phi}{\phi}\,\Delta Q_X,
\\[4pt]
\frac{\partial \pi^\phi}{\partial \Delta Q_M}
&=
\frac{1-\phi}{\phi}\,\Delta Q_M.
\end{aligned}
\]

Considering the above definitions, which is the more intuitive
algebra for \(\phi\)?

Current:

\[
\boxed{
\otimes_\phi
:=
1-(1-\phi_M)(1-\phi_X).
}
\]



% ============================================================
% 4) Replacing / substitution conventionally
% ============================================================

\[
\boxed{
4)\quad
\text{Replacing/substitution conventionally}
}
\]

Using the substiion \(P_\varphi\) by which must be concerned and defined as the natural coordinate system and first coordinate substitution in mind

\[
\frac{1}{p_{(\eta,\Delta_i)}\cdot p (i + \Delta_i)}.
\]


\[
\begin{aligned}
Q_X^L
\left(
\frac{1}{p_{(\eta,\Delta_i)} \cdot p}
\right)
&=
\overline{L}_{(\chi,\epsilon)}
\left[
\left(
P_{eq}
-
P_\varphi^{(\mathrm{ask})}
\right)^+
-
\left(
P_{eq}
-
P_\varphi^{(\mathrm{bid})}
\right)^+
\right].
\end{aligned}
\]

Then

\[
\begin{aligned}
d\widetilde{L}_{(\chi,\epsilon)}(i_K^\circ)
&=
\overline{L}_{(\chi,\epsilon)}
\left[
\delta\!\left(P_\varphi^{(\mathrm{ask})}\right)
-
\delta\!\left(P_\varphi^{(\mathrm{bid})}\right)
\right].
\end{aligned}
\]

where

\[
\delta:\text{Dirac function}.
\]

Hence,

\[
\begin{aligned}
\widetilde{L}_{(\chi,\epsilon)}(i_K^\circ)
&=
\int_{i_K^\circ}
d\widetilde{L}_{(\chi,\epsilon)}(i).
\end{aligned}
\]

% ============================================================
% 3) HODL, IL, R, LVR
% ============================================================

\[
3)\qquad
\left(
    \pi^{\mathrm{HODL}},
    \pi^{\mathrm{IL}},
    \pi^{R},
    \pi^{\mathrm{LVR}}
\right)
\]

\[
\frac{\partial \pi^{\mathrm{HODL}}}{\partial t}
=
\frac{\partial P_{\varphi}}{\partial t}
Q_X^L
\left[
    P_{\varphi}\bigl(i^\circ(t_0)\bigr)
\right]
\]

\[
\frac{\partial \pi^{\varphi}}{\partial t}
=
\frac{\partial \pi^{\varphi}}{\partial P_{\varphi}}
\,\partial P_{\varphi}
+
\frac{1}{2}
\frac{\partial^2 \pi^{\varphi}}
     {\partial P_{\varphi}^2}
\,d\langle P_{\varphi}\rangle_t
\]

> \(d\langle P_{\varphi}\rangle_t\) needs proper formulation
> under the discrete-calculus approach.

\[
\pi^{\mathrm{IL}}
\equiv
\pi^{\mathrm{HODL}}
-
\pi^{\varphi}
\]

hence,

\[
\frac{\partial \pi^{\mathrm{IL}}}{\partial t}
=
\frac{\partial \pi^{\mathrm{HODL}}}{\partial t}
-
\frac{\partial \pi^{\varphi}}{\partial t}.
\]

Define:

\[
\frac{\partial \pi^{R}}{\partial t}
=
\frac{\partial P_{\varphi}}{\partial t}
Q_X^L
\left(
    P_{\varphi}\bigl(i^\circ(t)\bigr)
\right)
\]

and therefore,

\[
\boxed{
\frac{\partial \pi^{\mathrm{LVR}}}{\partial t}
=
\frac{\partial \pi^{R}}{\partial t}
-
\frac{\partial \pi^{\varphi}}{\partial t}
}
\]


\[
\bar{\nu}_{\varphi}(t_0)
=
\frac{
    \varphi\left(
        Q_X^{L} + \Delta Q_X,\,
        Q_M^{L} + \Delta Q_M
    \right)
}{
    \varphi\left(
        Q_X^{L}, Q_M^{L}
    \right)
}
\equiv 1
\]

\[
\nu_{\varphi}(t) \in (0,1)
\qquad \text{is an integral.}
\]

\[
\bar{\nu}_{\varphi}(t)
=
\frac{
    \varphi\left(
        \displaystyle\int_{t_0}^{t}
        \left(Q_X^{L}-\Delta Q_X\right)\,dt,
        \displaystyle\int_{t_0}^{t}
        \left(Q_M^{L}-\Delta Q_M\right)\,dt
    \right)
}{
    \varphi\left(
        \displaystyle\int_{t_0}^{t} Q_X^{L}\,dt,
        \displaystyle\int_{t_0}^{t} Q_M^{L}\,dt
    \right)
}
\]


The strucuture we want is:

\[
	\begin{aligned}
		\nu_{\varphi} \, (\kappa_{\varphi};t) \equiv \kappa_{\varphi}^{g_{\varphi} (\cdot; i(t))} \equiv \frac{
    \varphi\left(
        \displaystyle\int_{t_0}^{t}
        \left(Q_X^{L}-\Delta Q_X\right)\,dt,
        \displaystyle\int_{t_0}^{t}
        \left(Q_M^{L}-\Delta Q_M\right)\,dt
    \right)
}{
    \varphi\left(
        \displaystyle\int_{t_0}^{t} Q_X^{L}\,dt,
        \displaystyle\int_{t_0}^{t} Q_M^{L}\,dt
    \right)
}
	\end{aligned}
\]

> The same way VLR wil walk along \gamma_{\varphi}, \phi already wals along utitlization, or perhaps the strucure is making u depend on kappa such athta then we pin the kernel on alpha_R as a functioj of kappa
