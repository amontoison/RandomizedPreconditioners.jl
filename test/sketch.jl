@testset "Nystrom Sketch" begin
    # Data
    Random.seed!(0)
    n, r_true = 500, 100
    A = randn(n, r_true)
    A = A*A'

    r = round(Int, r_true * 1.2)
    k = round(Int, 0.9*r)
    λ = eigvals(A; sortby=x->-x)
    Anys = RP.NystromSketch(A, k, r)
    @test size(Anys, 1) == n && size(Anys, 2) == n
    @test rank(Anys) == k
    @test λ[1:k] ≈ svdvals(Anys)

    @test λ[1:k] ≈ eigvals(Anys)
    @test ≈(RP.estimate_norm_E(A, Anys; q=20), opnorm(A - Matrix(Anys)); rtol=1e-2)

    k, r = k ÷ 2, r ÷ 2
    Anys = RP.NystromSketch(A, k, r)
    @test ≈(RP.estimate_norm_E(A, Anys; q=50), opnorm(A - Matrix(Anys)); rtol=2e-1)

    x = randn(n)
    y = Anys * x
    @test y ≈ Matrix(Anys) * x
    z = zeros(n)

    @testset "Adaptive Sketch Building" begin
        Anys_adapt = RP.adaptive_sketch(A, 2, RP.NystromSketch)
        @test round(128 - rank(Anys_adapt) * 1/.9) == 0       # Stops at r = 128, k = 115
        @test opnorm(A - Matrix(Anys_adapt)) <= 1e-6        
    end
end

@testset "EigenSketch" begin
    # Data
    Random.seed!(0)
    n, r1, r2 = 500, 60, 40
    r_true = r1+r2
    AAT(n, r) = randn(n, r) |> A->A*A'
    A = AAT(n, r1) - AAT(n, r2)

    r = round(Int, r_true * 1.2)
    k = round(Int, 0.9*r)
    A_sketch = RP.EigenSketch(A, k, r; check=true, q=5)
    @test size(A_sketch, 1) == n && size(A_sketch, 2) == n
    @test rank(A_sketch) == k
    λ = eigvals(A; sortby=x->-x) |> x->x[abs.(x) .≥ 1e-8]
    λhat =  eigvals(A_sketch) |> x->x[abs.(x) .≥ 1e-8]

    @test λ ≈ λhat
    @test RP.estimate_norm_E(A, A_sketch; q=20) <= 1e-8 && opnorm(A - Matrix(A_sketch)) <= 1e-8

    k, r = k ÷ 2, r ÷ 2
    A_sketch = RP.EigenSketch(A, k, r; q=100)
    @test ≈(RP.estimate_norm_E(A, A_sketch; q=100), opnorm(A - Matrix(A_sketch)); rtol=2e-1)

    x = randn(n)
    y = A_sketch * x
    @test y ≈ Matrix(A_sketch) * x
    z = zeros(n)

    @testset "Adaptive Sketch Building" begin
        Anys_adapt = RP.adaptive_sketch(A, 2, RP.EigenSketch)
        @test round(128 - rank(Anys_adapt) * 1/.9) == 0       # Stops at r = 128, k = 115
        @test opnorm(A - Matrix(Anys_adapt)) <= 1e-6        
    end
end

@testset "Randomized SVD" begin
    # Data
    Random.seed!(0)
    n, r1, r2 = 500, 60, 40
    r = r1+r2
    AAT(n, r) = randn(n, r) |> A->A*A'
    A = AAT(n, r1) - AAT(n, r2)
    B = randn(n, n÷2) |> svd |> x->(x.U[:, 1:r] * Diagonal(x.S[1:r]) * x.Vt[1:r, :])
    B = B*B'*B

    for M in [A, B]
        r = round(Int, r1 + r2 * 1.2)
        k = round(Int, 0.9*r)
        Mhat = RP.RandomizedSVD(M, k, r; q=5)
        @test size(Mhat, 1) == size(M, 1) && size(Mhat, 2) == size(M, 2)
        @test rank(Mhat) == k
        @test svdvals(M)[1:k] ≈ svdvals(Mhat)
        @test ≈(RP.estimate_norm_E(M, Mhat; q=20), opnorm(M - Matrix(Mhat)); rtol=1e-1)

        k, r = k ÷ 2, r ÷ 2
        Mhat = RP.RandomizedSVD(M, k, r; q=5)
        @test ≈(RP.estimate_norm_E(M, Mhat; q=50), opnorm(M - Matrix(Mhat)); rtol=1e-1)

        x = randn(size(Mhat, 2))
        y = Mhat * x
        @test y ≈ Matrix(Mhat) * x
    end

    @testset "Adaptive Sketch Building" begin
        B̂ = RP.adaptive_sketch(B, 2, RP.RandomizedSVD)
        @test round(128 - rank(B̂) * 1/.9) == 0       # Stops at r = 128, k = 115
        @test opnorm(B - Matrix(B̂)) <= 1e-6        
    end
    
end