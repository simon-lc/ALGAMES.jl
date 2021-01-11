################################################################################
# Residual
################################################################################
function residual!(prob::GameProblem{KN,n,m,T,SVd,SVx}) where {KN,n,m,T,SVd,SVx}
	residual!(prob, prob.pdtraj)
	return nothing
end

function residual!(prob::GameProblem{KN,n,m,T,SVd,SVx}, pdtraj::PrimalDualTraj{KN,n,m,T,SVd}) where {KN,n,m,T,SVd,SVx}
	N = prob.probsize.N
	p = prob.probsize.p
    pu = prob.probsize.pu
	core = prob.core
	model = prob.model
	game_obj = prob.game_obj

	# Initialization
	prob.core.res .= 0.0
    stamp = VStamp()
	∇dyn = zeros(MMatrix{n,(n+m),T,n*(n+m)})

	# Cost
	cost_gradient!(game_obj, pdtraj)
	for i = 1:p
		# State cost
		for k = 1:N
			stampify!(stamp, :opt, i, :x, 1, k)
			valid(stamp, N, p) ? add2sub(core.res_sub[stamp], game_obj.E[i].cost[k].q) : nothing
		end
		# Control Cost
		for k = 1:N-1
			stampify!(stamp, :opt, i, :u, i, k)
			valid(stamp, N, p) ? add2sub(core.res_sub[stamp], game_obj.E[i].cost[k].r[pu[i]]) : nothing
		end
	end
	# Dynamics penalty
	for k = 1:N-1
		∇dynamics!(∇dyn, model, pdtraj, k)
		for i = 1:p
			λik = pdtraj.du[i][k]
			stampify!(stamp, :opt, i, :x, 1, k)
			valid(stamp, N, p) ? add2sub(core.res_sub[stamp], ∇dyn[:,core.dyn[:x][1]]'*λik) : nothing
			stampify!(stamp, :opt, i, :u, i, k)
			valid(stamp, N, p) ? add2sub(core.res_sub[stamp], ∇dyn[:,core.dyn[:u][i]]'*λik) : nothing
			stampify!(stamp, :opt, i, :x, 1, k+1)
			valid(stamp, N, p) ? add2sub(core.res_sub[stamp], -λik) : nothing
		end
	end

	# Constraints
	constraint_residual!(prob, pdtraj)

	# Dynamics
    for k = 1:N-1
        stampify!(stamp, :dyn, 1, :x, 1, k)
        valid(stamp, N, p) ? add2sub(core.res_sub[stamp], dynamics_residual(model, pdtraj, k)) : nothing # shouldn't allocate
    end
    return nothing
end


################################################################################
# Residual Jacobian
################################################################################

function residual_jacobian!(prob::GameProblem{KN,n,m,T,SVd,SVx}) where {KN,n,m,T,SVd,SVx}
	residual_jacobian!(prob, prob.pdtraj)
	return nothing
end

function residual_jacobian!(prob::GameProblem{KN,n,m,T,SVd,SVx},
	pdtraj::PrimalDualTraj{KN,n,m,T,SVd}) where {KN,n,m,T,SVd,SVx}
    N = prob.probsize.N
	p = prob.probsize.p
    pu = prob.probsize.pu
	model = prob.model
	core = prob.core
    game_obj = prob.game_obj

	# Reset!
	sparse_zero!(prob.core.jac)

    # Allocations
    stamp = Stamp()
    ∇dyn = zeros(MMatrix{n,(n+m),T,n*(n+m)})

	# Cost function
	cost_hessian!(game_obj, pdtraj)
	# Cost
	for i = 1:p
		# State cost
		for k = 1:N
			stampify!(stamp, :opt, i, :x, 1, k, :x, 1, k)
			valid(stamp, N, p) ? add2sub(core.jac_sub[stamp], game_obj.E[i].cost[k].Q) : nothing
		end
		# Control cost
		for k = 1:N-1
			stampify!(stamp, :opt, i, :u, i, k, :u, i, k)
			valid(stamp, N, p) ? add2sub(core.jac_sub[stamp], game_obj.E[i].cost[k].R[pu[i],pu[i]]) : nothing
		end
	end

	# Constraints
	constraint_jacobian_residual!(prob, pdtraj)

	# Dynamics
	for k = 1:N-1
        ∇dynamics!(∇dyn, model, pdtraj, k)
        # Bottom Left
        stampify!(stamp, :dyn, 1, :x, 1, k, :x, 1, k)
		∇dyn_x = ∇dyn[:,core.dyn[:x][1]]
		valid(stamp, N, p) ? add2sub(core.jac_sub[stamp], ∇dyn[:,core.dyn[:x][1]]) : nothing
        for i = 1:p
            stampify!(stamp, :dyn, 1, :x, 1, k, :u, i, k)
            valid(stamp, N, p) ? add2sub(core.jac_sub[stamp], ∇dyn[:,core.dyn[:u][i]]) : nothing
        end
        stampify!(stamp, :dyn, 1, :x, 1, k, :x, 1, k+1)
        valid(stamp, N, p) ? addI2sub(core.jac_sub[stamp], -1.0) : nothing
        # Top Right
        for i = 1:p
            stampify!(stamp, :opt, i, :x, 1, k, :λ, i, k)
            valid(stamp, N, p) ? add2sub(core.jac_sub[stamp], ∇dyn[:,core.dyn[:x][1]]') : nothing
            stampify!(stamp, :opt, i, :u, i, k, :λ, i, k)
            valid(stamp, N, p) ? add2sub(core.jac_sub[stamp], ∇dyn[:,core.dyn[:u][i]]') : nothing
            stampify!(stamp, :opt, i, :x, 1, k+1, :λ, i, k)
            valid(stamp, N, p) ? addI2sub(core.jac_sub[stamp], -1.0) : nothing
        end
    end
    return nothing
end

function regularize_residual_jacobian!(prob::GameProblem{KN,n,m,T,SVd,SVx}) where {KN,n,m,T,SVd,SVx}
	N = prob.probsize.N
	p = prob.probsize.p
	pu = prob.probsize.pu
	core = prob.core
	opts = prob.opts

	stamp = Stamp()
	for k = 1:N-1
		for i = 1:p
			stampify!(stamp, :opt, i, :x, 1, k+1, :x, 1, k+1)
			valid(stamp, N, p) ? addI2sub(core.jac_sub[stamp], opts.reg.x) : nothing
			stampify!(stamp, :opt, i, :u, i, k, :u, i, k)
			valid(stamp, N, p) ? addI2sub(core.jac_sub[stamp], opts.reg.u) : nothing
		end
	end
	return nothing
end

################################################################################
# Helpers
################################################################################

function add2sub(v::SubArray, e)
	v .+= e
	return nothing
end

function add2sub(v::SubArray, e::Diagonal{T,SVector{n,T}}) where {n,T}
	for i = 1:n
		v[i,i] += e[i,i]
	end
	return nothing
end

function addI2sub(v::SubArray, e)
	n = size(v)[1]
	for i = 1:n
		v[i,i] += e
	end
	return nothing
end

function sparse_zero!(spm::SparseMatrixCSC)
	n = length(spm.nzval)
	for i = 1:n
		spm.nzval[i] = 0.0
	end
	return nothing
end

################################################################################
# Printers
################################################################################

function display_solver_header()
	@printf(
		"%-3s %-2s %-2s %-6s %-6s %-6s \n",
		"out",
		"in",
		"α",
		"Δ",
		"res",
		"reg",
		)
	return nothing
end

function display_solver_data(k, l, j, Δ, res_norm, reg)#, condi, loss, val_scale, jac_scale)
	@printf(
		"%-3s %-2s %-2s %-6s %-6s %-6s \n",
		k,
		l,
		j,
		@sprintf("%.0e", Δ),
		@sprintf("%.0e", res_norm),
		@sprintf("%.0e", reg.x),
		)
	return nothing
end
