### A Pluto.jl notebook ###
# v0.19.25

using Markdown
using InteractiveUtils

# This Pluto notebook uses @bind for interactivity. When running this notebook outside of Pluto, the following 'mock version' of @bind gives bound variables a default value (instead of an error).
macro bind(def, element)
    quote
        local iv = try Base.loaded_modules[Base.PkgId(Base.UUID("6e696c72-6542-2067-7265-42206c756150"), "AbstractPlutoDingetjes")].Bonds.initial_value catch; b -> missing; end
        local el = $(esc(element))
        global $(esc(def)) = Core.applicable(Base.get, el) ? Base.get(el) : iv(el)
        el
    end
end

# ╔═╡ 58cc5e90-9081-49bb-a838-315843a58824
# ╠═╡ show_logs = false
begin
	using Pkg
	Pkg.activate(mktempdir())
	Pkg.add("CairoMakie")
	Pkg.add("NIfTI")
	Pkg.add("PlutoUI")
	Pkg.add("CSV")
	Pkg.add("DataFrames")
	Pkg.add("DelimitedFiles")
	Pkg.add("Random")
	Pkg.add("UUIDs")
	Pkg.add(url="https://github.com/hstrey/BDTools.jl")

	using BDTools
	using CairoMakie
	using PlutoUI
	using NIfTI
	using CSV
	using DataFrames
	using DelimitedFiles
	using Random
	using UUIDs
end

# ╔═╡ 3f422f2b-5f32-4a00-9e07-ad1a14d47836
TableOfContents()

# ╔═╡ 2f6eced1-28c9-4b7b-919f-4884be053947
md"""
# Milestone 1
"""

# ╔═╡ 218f4715-958c-477c-9cad-79f65eec7618
md"""
## Load Phantom, Logs, & Acqusition Times
"""

# ╔═╡ 734367e4-2857-4583-b90c-a2a18b290f16
md"""
#### Upload Files
Ensure log and acquisition files are in `.csv` format & phantom file is in `.nii` or `.nii.gz` format. Then click submit

Upload Logs: $(@bind log_file FilePicker())


Upload Acquisition Times: $(@bind acq_file FilePicker())


Upload Phantom Scan: $(@bind nifti_file FilePicker())
"""

# ╔═╡ bf1c2269-2409-494b-ab3e-408e7bc65c87
files_ready = (log_file != nothing) && (acq_file != nothing) && (nifti_file != nothing)

# ╔═╡ 7fef0561-8020-4744-b29c-f5c7d6c77703
if files_ready
	df_log = CSV.read(log_file["data"], DataFrame)
	
	df_acq = CSV.read(acq_file["data"], DataFrame)
	
	temp_file_path = joinpath(tempdir(), "temp_" * string(uuid4()) * ".nii")
	open(temp_file_path, "w") do f
		write(f, nifti_file["data"])
	end
	global phantom = niread(temp_file_path)
	rm(temp_file_path)
end

# ╔═╡ 170677c4-dd5c-4232-8366-9a4df9d82798
md"""
## Identify Good Slices
"""

# ╔═╡ db0692d6-1fc5-4db3-aa65-417e4bfbc24a
function good_slice_info(good_slices_first, good_slices_last)
	
	return PlutoUI.combine() do Child
		
		inputs = [
			md""" $(good_slices_first): $(
				Child(TextField())
			)""",
			md""" $(good_slices_last): $(
				Child(TextField())
			)"""
		]
		
		md"""
		#### Good Slices
		Select the range of good slices between 1 to 60 by scrolling through the slider and note when the first good slice starts and when the last good slice ends
		$(inputs)
		"""
	end
end

# ╔═╡ 46e0d850-e052-4aaf-9ce2-be61d6b80d65
if files_ready
	@bind g_slices confirm(good_slice_info("First good slice: ", "Last good slice: "))
end

# ╔═╡ dbd4f412-6e9a-4d0f-a050-55b10c74d40b
good_slices_files_ready = files_ready && (g_slices[1] != "" || g_slices[2] != "" )

# ╔═╡ 56082c7d-50cf-4c83-aa20-f988041a3018
if files_ready
	@bind a_slider PlutoUI.Slider(axes(phantom, 3), ; default=8, show_value=true)
end

# ╔═╡ 90e22e8f-f5cf-4351-890e-0159c6b24d36
let
	if files_ready
		f = Figure()
		ax = CairoMakie.Axis(f[1, 1])
		heatmap!(phantom[:, :, a_slider, 1], colormap=:grays)
		f
	end
end

# ╔═╡ 26601fa7-cd58-48e9-8e3e-7cdb16c4a6a8
if good_slices_files_ready
	good_slices = collect(parse(Int, g_slices[1]):parse(Int, g_slices[2]));
end;

# ╔═╡ 186456eb-1ea6-40b8-8a86-2644149d59c4
function static_slice_info(good_slices_first, good_slices_last)
	
	return PlutoUI.combine() do Child
		
		inputs = [
			md""" $(good_slices_first): $(
				Child(TextField(default="1"))
			)""",
			md""" $(good_slices_last): $(
				Child(TextField(default="200"))
			)"""
		]
		
		md"""
		#### Static Slices
		Select the range of good slices between 1 to 60 by scrolling through the slider and note when the first good slice starts and when the last good slice ends
		$(inputs)
		"""
	end
end

# ╔═╡ a0ce0c4b-140d-4c05-bbd3-34ff6779c942
if files_ready
	@bind static_ranges confirm(static_slice_info("Starting static slice: ", "Ending static slice: "))
end

# ╔═╡ 6640cd1b-4e2f-4458-b0c7-62f1595a6cd2
if files_ready
	@bind b_slider PlutoUI.Slider(axes(phantom, 4), ; default=div(size(phantom, 4), 2), show_value=true)
end

# ╔═╡ 9f97b9ec-3b4a-47e6-9aff-b2a3b10200b5
let
	if files_ready
		half_slice = good_slices[div(length(good_slices), 2)]
		f = Figure()
		ax = CairoMakie.Axis(f[1, 1])
		heatmap!(phantom[:, :, half_slice, b_slider], colormap=:grays)
		f
	end
end

# ╔═╡ 5b2903ee-0ccf-4f91-b8a3-fc3a02282a3d
if files_ready
	num_static_range_low = parse(Int, static_ranges[1])
	num_static_range_high = parse(Int, static_ranges[2])
	static_range = num_static_range_low:num_static_range_high
end;

# ╔═╡ f92af1dc-5b1f-4242-b041-ba4c2c9319c9
if good_slices_files_ready
	good_slices_matrix = Int.(hcat(zeros(size(phantom, 3)), collect(axes(phantom, 3))))
	for i in good_slices
		idx = findall(x -> x == i, good_slices_matrix[:, 2])
		good_slices_matrix[idx..., 1] = 1
	end
end;

# ╔═╡ d936235d-3ac7-40d4-a259-9cf81e9df3ee
md"""
## Calculate Average Static Phantom
"""

# ╔═╡ 3472bcaf-791f-45bb-938d-53f837bf6bd6
if good_slices_files_ready
	good_slices_range = first(good_slices):last(good_slices)
end;

# ╔═╡ 31082a05-71a2-437d-a076-485eb097c94f
if good_slices_files_ready
	phantom_ok = phantom[:, :, good_slices_range, static_range]
	phantom_ok = Float64.(convert(Array, phantom))
end;

# ╔═╡ 48e647bd-c3b1-43f8-85d7-a1f299d05aee
if good_slices_files_ready
	sph = staticphantom(phantom_ok, good_slices_matrix; staticslices=static_range)
end;

# ╔═╡ fd9c05fd-6ad6-4888-a080-5a5c1ba3402f
if good_slices_files_ready
	@bind c_slider PlutoUI.Slider(good_slices, ; default=good_slices[div(length(good_slices), 2)], show_value=true)
end

# ╔═╡ e2918f9a-ebce-4b39-8301-ed55d6f7fd73
if good_slices_files_ready
	@bind d_slider PlutoUI.Slider(axes(phantom, 4), ; default=div(size(phantom, 4), 2), show_value=true)
end

# ╔═╡ e3354fbf-e962-41f7-893c-6406968844e1
if good_slices_files_ready
	ave = BDTools.genimg(sph.data[:, :, c_slider])
end;

# ╔═╡ 6c0ef15f-394c-48bd-bde5-182b3fcd30dc
let
	if good_slices_files_ready
		f = Figure(resolution=(1000, 700))
		ax = CairoMakie.Axis(
			f[1, 1],
			title="Raw 4D fMRI"
		)
		heatmap!(phantom[:, :, c_slider, d_slider], colormap=:grays)
	
		ax = CairoMakie.Axis(
			f[1, 2],
			title="Average Static Image"
		)
		heatmap!(ave[:, :], colormap=:grays)
		f
	end
end

# ╔═╡ c28dfcd6-a748-4ab0-acda-318699c100f2
md"""
## Create Mask for B-field Correction
"""

# ╔═╡ 25374920-81c5-4533-8599-8ff8aae67ab4
if good_slices_files_ready
	@bind c_slider2 PlutoUI.Slider(good_slices, ; default=8, show_value=true)
end

# ╔═╡ f5ff7f70-c354-446c-a185-e43b4eb34144
if good_slices_files_ready
	msk = BDTools.segment3(sph.data[:, :, c_slider2])
end;

# ╔═╡ 8e121b9c-572f-41ee-89c9-9af3ba214508
let
	if good_slices_files_ready
		cartesian_indices1 = findall(x -> x == 2, msk.image_indexmap)
		x_indices1 = [index[1] for index in cartesian_indices1]
		y_indices1 = [index[2] for index in cartesian_indices1]
		xys1 = hcat(x_indices1, y_indices1)
	
		cartesian_indices2 = findall(x -> x == 3, msk.image_indexmap)
		x_indices2 = [index[1] for index in cartesian_indices2]
		y_indices2 = [index[2] for index in cartesian_indices2]
		xys2 = hcat(x_indices2, y_indices2)
	
		f = Figure()
		ax = CairoMakie.Axis(
			f[1, 1],
			title = "Raw Phantom + Mask"
		)
		heatmap!(sph.data[:, :, c_slider2], colormap=:grays)
		scatter!(xys1[:, 1], xys1[:, 2], color=:red)
		scatter!(xys2[:, 1], xys2[:, 2], color=:blue)
		f
	end
end

# ╔═╡ 8632a5da-e705-477d-a6bd-06b13deb92ae
md"""
## Run B-field Correction on Static Image
"""

# ╔═╡ 097485dc-2a65-46b7-b71a-09276d8013c5
md"""
## Correct 4D Phantom w/ Bias Field
"""

# ╔═╡ 04c8a79d-2997-4693-8ee6-5922f101bfb5
md"""
# Milestone 2
"""

# ╔═╡ e38742a4-1806-4dc2-8594-1efbd218b913
md"""
## Fit Center & Radius
"""

# ╔═╡ f01759ac-9e02-4c85-99d7-641c4531b920
# Original Centers
ecs = BDTools.centers(sph);

# ╔═╡ f84f11ff-44c6-4e2e-9374-36ab73143961
# Predicted center axis
begin
	rng = collect(-1.:0.15:1.)
	cc = map(t->BDTools.predictcenter(sph, t), rng)
end;

# ╔═╡ bc2e0cb0-3820-4ea4-a28d-707ae8111dc4
first(cc)

# ╔═╡ d92e1d8d-9157-4222-ad14-f5399b241824
# Fitted Centers
xy = BDTools.fittedcenters(sph);

# ╔═╡ 1a212845-6b86-4405-91ee-e4163dd3609d
let
	f = Figure()
	ax = CairoMakie.Axis(f[1, 1])
	scatter!(ecs[:, 1], ecs[:, 2], label="Centers")
	lines!(map(first, cc), map(last, cc), label="Predicted Axis", color=:orange)
	scatter!(xy[:, 1], xy[:, 2], label="Fitted Centers", color=:green)
	axislegend(ax, position=:lt)
	f
end

# ╔═╡ 8d99a404-7ef5-4dee-8b17-e9f422735dc6
md"""
## Calculate Ground Truth Phantom
Users might need to input `threshold`
"""

# ╔═╡ aaf206d7-2688-41db-b1df-f0b917c8a720
if good_slices_files_ready
	initpos, col, quant= 20, 11, 2^13
	@assert size(df_log, 2) > col "Wrong size"
	pos = df_log[!, "EndPos"]
	firstrotidx = findfirst(e -> e > 20, pos)
	# adjust to [-π:π] range
    angles = [a > π ? a-2π : a  for a in (pos ./ quant).*(2π)]
end

# ╔═╡ 13b38cac-3253-4add-8968-a70a1798774f
if good_slices_files_ready
	res = BDTools.groundtruth(sph, phantom_ok, angles; startmotion=firstrotidx, threshold=.95)
end;

# ╔═╡ 7263cbf0-3947-46fa-9193-e9a37ef566f8
if good_slices_files_ready
	data, sliceidx, maskcoords = res.data, res.sliceindex, res.maskindex
end;

# ╔═╡ 05d0bcae-d089-496d-90f2-729e3cce453e
md"""
## Fit Centerline of Rotation
"""

# ╔═╡ 6e042a09-b2c7-46c9-a235-9a250fe77fdb
# begin
# 	x = 42
# 	y = 52
# 	# get a coordinate index
# 	c = CartesianIndex(x,y)
# 	cidx = findfirst(m -> m == c, maskcoords)
# end

# ╔═╡ 78e6e1fb-980b-46d9-a2f7-fd40931916a7
# @bind z PlutoUI.Slider(eachindex(sliceidx); default=3, show_value=true)

# ╔═╡ db725482-ce85-47f6-9fba-f052783e9bb2
# let
# 	f = Figure()
# 	ax = CairoMakie.Axis(f[1, 1])
#     lines!(data[:, cidx, z, 2], label="original")
#     lines!(data[:, cidx, z, 1], label="prediction")
# 	axislegend(ax)
# 	f
# end

# ╔═╡ b08f21d6-bef4-4f25-b148-5ac830353655
md"""
## Calculate Ground Truth By Rotations & Interpolation
"""

# ╔═╡ 86cf2af7-658d-4794-ac47-c1f69a3793b7
# begin
# 	degrees = 0
# 	α = deg2rad(degrees)
# 	γ = BDTools.findinitialrotation(sph, z)
# end;

# ╔═╡ 378da718-25bc-49ab-8793-e28392f666cc
# origin, a, b = BDTools.getellipse(sph, z);

# ╔═╡ 172a92b4-a1c1-4cea-9a96-39c38349b093
# coords = [BDTools.ellipserot(α, γ, a, b)*([i,j,z].-origin).+origin for i in 1:sz[1], j in 1:sz[2]];

# ╔═╡ 2c0eec6f-f30d-4271-8e98-11e21c75675b
# # interpolate intensities
# sim = map(c->sph.interpolation(c...), coords);

# ╔═╡ 5063e4e3-f6d8-4cfa-bad8-26a1d925396b
# # generate image
# gen = sim |> BDTools.genimg;

# ╔═╡ e6c3ef9f-3b26-4911-af3a-e0d6ca3cc88d
# let
# 	f = Figure(resolution=(1000, 700))
# 	ax = CairoMakie.Axis(
# 		f[1, 1],
# 		title="Average Static Image @ Slice $(c_slider)"
# 	)
# 	heatmap!(ave, colormap=:grays)

# 	ax = CairoMakie.Axis(
# 		f[1, 2],
# 		title="Generated Image @ Slice $(c_slider) & Rotated $(degrees) Degrees"
# 	)
# 	heatmap!(gen[:, :], colormap=:grays)
# 	f
# end

# ╔═╡ c9e848e2-6005-4482-8743-08a6b457b8bb
md"""
# Milestone 3
"""

# ╔═╡ 9fe4b846-c0bf-4783-8f7d-f3ebebf2c5bc
md"""
## Calulcate Quality Control Measures
"""

# ╔═╡ a938ec58-50f1-41af-bf82-0bdae52d8cbc
md"""
# Milestone 4
"""

# ╔═╡ 8ca6b08d-3342-438c-b941-23c43cfcd75b
md"""
## Train Neural Network w/ Time Series
"""

# ╔═╡ 608ca30b-c52f-4d97-87a6-0544f53af201
md"""
# Milestone 5
"""

# ╔═╡ cf085db1-c0fb-4d8d-9f75-dcd780fd12a9
md"""
## Processed 4D fMRI from Neural Network
"""

# ╔═╡ Cell order:
# ╠═58cc5e90-9081-49bb-a838-315843a58824
# ╠═3f422f2b-5f32-4a00-9e07-ad1a14d47836
# ╟─2f6eced1-28c9-4b7b-919f-4884be053947
# ╟─218f4715-958c-477c-9cad-79f65eec7618
# ╟─734367e4-2857-4583-b90c-a2a18b290f16
# ╠═bf1c2269-2409-494b-ab3e-408e7bc65c87
# ╠═7fef0561-8020-4744-b29c-f5c7d6c77703
# ╟─170677c4-dd5c-4232-8366-9a4df9d82798
# ╟─46e0d850-e052-4aaf-9ce2-be61d6b80d65
# ╠═dbd4f412-6e9a-4d0f-a050-55b10c74d40b
# ╟─db0692d6-1fc5-4db3-aa65-417e4bfbc24a
# ╟─56082c7d-50cf-4c83-aa20-f988041a3018
# ╟─90e22e8f-f5cf-4351-890e-0159c6b24d36
# ╠═26601fa7-cd58-48e9-8e3e-7cdb16c4a6a8
# ╟─a0ce0c4b-140d-4c05-bbd3-34ff6779c942
# ╟─186456eb-1ea6-40b8-8a86-2644149d59c4
# ╟─6640cd1b-4e2f-4458-b0c7-62f1595a6cd2
# ╟─9f97b9ec-3b4a-47e6-9aff-b2a3b10200b5
# ╠═5b2903ee-0ccf-4f91-b8a3-fc3a02282a3d
# ╠═f92af1dc-5b1f-4242-b041-ba4c2c9319c9
# ╟─d936235d-3ac7-40d4-a259-9cf81e9df3ee
# ╠═3472bcaf-791f-45bb-938d-53f837bf6bd6
# ╠═31082a05-71a2-437d-a076-485eb097c94f
# ╠═48e647bd-c3b1-43f8-85d7-a1f299d05aee
# ╟─fd9c05fd-6ad6-4888-a080-5a5c1ba3402f
# ╟─e2918f9a-ebce-4b39-8301-ed55d6f7fd73
# ╠═e3354fbf-e962-41f7-893c-6406968844e1
# ╟─6c0ef15f-394c-48bd-bde5-182b3fcd30dc
# ╟─c28dfcd6-a748-4ab0-acda-318699c100f2
# ╟─25374920-81c5-4533-8599-8ff8aae67ab4
# ╠═f5ff7f70-c354-446c-a185-e43b4eb34144
# ╟─8e121b9c-572f-41ee-89c9-9af3ba214508
# ╟─8632a5da-e705-477d-a6bd-06b13deb92ae
# ╟─097485dc-2a65-46b7-b71a-09276d8013c5
# ╟─04c8a79d-2997-4693-8ee6-5922f101bfb5
# ╟─e38742a4-1806-4dc2-8594-1efbd218b913
# ╠═f01759ac-9e02-4c85-99d7-641c4531b920
# ╠═f84f11ff-44c6-4e2e-9374-36ab73143961
# ╠═bc2e0cb0-3820-4ea4-a28d-707ae8111dc4
# ╠═d92e1d8d-9157-4222-ad14-f5399b241824
# ╟─1a212845-6b86-4405-91ee-e4163dd3609d
# ╟─8d99a404-7ef5-4dee-8b17-e9f422735dc6
# ╠═aaf206d7-2688-41db-b1df-f0b917c8a720
# ╠═13b38cac-3253-4add-8968-a70a1798774f
# ╠═7263cbf0-3947-46fa-9193-e9a37ef566f8
# ╟─05d0bcae-d089-496d-90f2-729e3cce453e
# ╠═6e042a09-b2c7-46c9-a235-9a250fe77fdb
# ╠═78e6e1fb-980b-46d9-a2f7-fd40931916a7
# ╠═db725482-ce85-47f6-9fba-f052783e9bb2
# ╟─b08f21d6-bef4-4f25-b148-5ac830353655
# ╠═86cf2af7-658d-4794-ac47-c1f69a3793b7
# ╠═378da718-25bc-49ab-8793-e28392f666cc
# ╠═172a92b4-a1c1-4cea-9a96-39c38349b093
# ╠═2c0eec6f-f30d-4271-8e98-11e21c75675b
# ╠═5063e4e3-f6d8-4cfa-bad8-26a1d925396b
# ╠═e6c3ef9f-3b26-4911-af3a-e0d6ca3cc88d
# ╟─c9e848e2-6005-4482-8743-08a6b457b8bb
# ╟─9fe4b846-c0bf-4783-8f7d-f3ebebf2c5bc
# ╟─a938ec58-50f1-41af-bf82-0bdae52d8cbc
# ╟─8ca6b08d-3342-438c-b941-23c43cfcd75b
# ╟─608ca30b-c52f-4d97-87a6-0544f53af201
# ╟─cf085db1-c0fb-4d8d-9f75-dcd780fd12a9
