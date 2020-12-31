################################################################################
# GameOptions
################################################################################

@with_kw mutable struct Options{T}
    # Options
	"Gauss-newton convergence criterion: tolerance."
	θ::T=1e-2

	# Regularization
	"Regularization of the residual and residual Jacobian."
	regularize::Bool=true

	# "Current Jacobian regularization for each primal-dual variables."
	# reg::Regularizer{T}=Regularizer()

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

################################################################################
# GameObjective
################################################################################

mutable struct GameObjective
	p::Int
	obj::Vector{Objective}
end

function GameObjective(Q::Vector{DQ}, R::Vector{DR}, xf::Vector{SVx}, uf::Vector{SVu},
	N::Int, model::AbstractGameModel) where {DQ,DR,SVx,SVu}
	T = eltype(xf[1])
	n = model.n
	m = model.m
	p = model.p
	@assert length(Q) == length(R) == length(xf) == length(uf)

	obj = Vector{Objective}(undef, p)
	for i = 1:p
		Qi = Diagonal(SVector{n,T}(expand_vector(diag(Q[i]), model.pz[i], n)))
		Ri = Diagonal(SVector{m,T}(expand_vector(diag(R[i]), model.pu[i], m)))
		Rf = Diagonal(zeros(SVector{m,T}))
		xfi = SVector{n,T}(expand_vector(xf[i], model.pz[i], n))
		ufi = SVector{m,T}(expand_vector(uf[i], model.pu[i], m))
		cost = LQRCost(Qi,Ri,xfi,ufi,checks=false)
		cost_term = LQRCost(Qi,Rf,xfi,checks=false)
		obj[i] = Objective(cost, cost_term, N)
	end
	return GameObjective(p,obj)
end

function expand_vector(v::AbstractVector{T}, inds::AbstractVector{Int}, n::Int) where {T}
	V = zeros(n)
	V[inds] = v
	return V
end

################################################################################
# GameConstraintList
################################################################################

mutable struct GameConstraintList
	p::Int
	conlist::Vector{TrajectoryOptimization.AbstractConstraintSet}
end

function GameConstraintList(conlists::Vector{<:TrajectoryOptimization.AbstractConstraintSet})
	p = length(conlists)
	return GameConstraintList(p, conlists)
end

################################################################################
# GameProblem
################################################################################

mutable struct GameProblem{SVx}
    probsize::ProblemSize
    core::NewtonCore
	x0::SVx
    game_obj::GameObjective
    game_conlist::GameConstraintList
    traj::Traj
    opts::Options
	stats::Statistics
end

function GameProblem(N::Int, dt::T, x0::SVx, model::AbstractGameModel, opts::Options,
	game_obj::GameObjective, game_conlist::GameConstraintList
	) where {T,SVx}

	probsize = ProblemSize(N,model)
	traj = Traj(model.n,model.m,dt,N)
	core = NewtonCore(probsize)
	stats = Statistics()
	TYPE = typeof.((x0,))
	return GameProblem{TYPE...}(probsize, core, x0, game_obj, game_conlist, traj, opts, stats)
end
