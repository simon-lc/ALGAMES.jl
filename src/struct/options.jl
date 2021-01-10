################################################################################
# GameOptions
################################################################################

@with_kw mutable struct Options{T}
    # Options
	"Gauss-newton convergence criterion: tolerance."
	θ::T=1e-2

	"Initialization function of the primal dual vector."
	f_init::Function=rand

	"Initialization amplitude of the primal dual vector."
	amplitude_init::T=1e-8

	# Regularization
	"Regularization of the residual and residual Jacobian."
	regularize::Bool=true

	"Current Jacobian regularization for each primal-dual variables."
	reg::Regularizer{T}=Regularizer()

	"Initial Jacobian regularization."
	reg_0::T=1e-3

	# Line search
	"Initial step size."
	α_0::T=1.0

	"Line search increase step."
	α_increase::T=1.2

	"Line search decrease step."
	α_decrease::T=0.5

	"Expected residual improvement."
	β::T=0.01

	"Number of line search iterations."
	ls_iter::Int=25

	# Augmented Lagrangian Penalty
	"Initial augmented Lagrangian penalty."
	ρ_0::T=1.0

	"Fixed augmented Lagrangian penalty on the residual used for the line search trials."
	ρ_trial::T=1.0

	"Penalty increase step."
	ρ_increase::T=10.0

	"Maximum augmented Lagrangian penalty."
	ρ_max::T=1e7

	"Maximum Lagrange multiplier."
	λ_max::T=1e7

	# Augmented Lagrangian iterations.
	"Outer loop iterations."
	outer_iter::Int=7

	"Inner loop iterations."
	inner_iter::Int=20

	# Problem Scaling
	"Objective function scaling."
	γ::T=1e0

	# MPC
	"Number of time steps simulated with MPC"
	mpc_horizon::Int=20

	"Rate of the upsampling used for simulaion and feedback control in the MPC"
	upsampling::Int=2

	# Printing
	"Displaying the inner step results."
	inner_print::Bool=true

	"Displaying the outer step results."
	outer_print::Bool=true
end