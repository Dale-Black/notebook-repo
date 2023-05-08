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

# ╔═╡ 866b498e-52cc-461a-90dc-bfd6d53dd80d
# ╠═╡ show_logs = false
begin
	using Pkg
	Pkg.activate(mktempdir())
	Pkg.add("CairoMakie")
	Pkg.add("NIfTI")
	Pkg.add("PlutoUI")
	Pkg.add("CSV")
	Pkg.add("DataFrames")
	Pkg.add("UUIDs")
	Pkg.add(url="https://github.com/hstrey/BDTools.jl")

	using BDTools
	using CairoMakie
	using PlutoUI
	using NIfTI
	using CSV
	using DataFrames
	using UUIDs
end

# ╔═╡ e7a428ce-0489-43c3-8c5a-bae818f0ca03
TableOfContents()

# ╔═╡ dc6717ba-25fb-4f7d-933a-18dc69fea34d
md"""
# Load Phantom, Logs, & Acqusition Times
"""

# ╔═╡ d90a11ce-52fd-48e4-9cb1-755bc2b29e51
function upload_files(logs, acqs, phtm)
	
	return PlutoUI.combine() do Child
		
		inputs = [
			md""" $(logs): $(@bind log_file FilePicker())""",
			md""" $(acqs): $(@bind acq_file FilePicker())""",
			md""" $(phtm): Upload Phantom Scan: $(@bind nifti_file FilePicker())"""
		]
		
		md"""
		#### Upload Files
		Ensure log and acquisition files are in `.csv` format & phantom file is in `.nii` or `.nii.gz` format. Then click submit
		$(inputs)
		"""
	end
end

# ╔═╡ d2e0accd-2395-4115-8842-e9176a0a132e
confirm(upload_files("Upload Logs: ", "Upload Acquisition Times: ", "Upload Phantom Scan: "))

# ╔═╡ 835f1748-0940-4a39-abb6-afa6ef8c4b90
files_ready = (log_file != nothing) && (acq_file != nothing) && (nifti_file != nothing)

# ╔═╡ 19b12720-4bd9-4790-84d0-9cf660d8ed70
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

# ╔═╡ 7f2148e2-8649-4fb6-a50b-3dc54bca7505
md"""
# Identify Good Slices
"""

# ╔═╡ 6a8117e0-e450-46d7-897f-0503d71f06af
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

# ╔═╡ 8eb754de-37b7-45fb-a7fc-c14c11e0216f
if files_ready
	@bind g_slices confirm(good_slice_info("First good slice: ", "Last good slice: "))
end

# ╔═╡ 7eacbaef-eae0-426a-be36-9c00a3b09d1b
good_slices_files_ready = files_ready && (g_slices[1] != "" || g_slices[2] != "" )

# ╔═╡ 49557d91-e4de-486b-99ed-3d564c7b7960
if files_ready
	@bind a_slider PlutoUI.Slider(axes(phantom, 3), ; default=8, show_value=true)
end

# ╔═╡ 04c7cf73-fa75-45e1-aafe-4ca658706289
let
	if files_ready
		f = Figure()
		ax = CairoMakie.Axis(f[1, 1])
		heatmap!(phantom[:, :, a_slider, 1], colormap=:grays)
		f
	end
end

# ╔═╡ f11be125-facc-44ff-8d00-8cd748d6d110
if good_slices_files_ready
	good_slices = collect(parse(Int, g_slices[1]):parse(Int, g_slices[2]));
end;

# ╔═╡ 8724296c-6118-4c0f-bea4-3173222a40cf
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

# ╔═╡ 877c4ec3-5c00-496a-b4e0-d09fc46fd207
if files_ready
	@bind static_ranges confirm(static_slice_info("Starting static slice: ", "Ending static slice: "))
end

# ╔═╡ 1d1fa36d-774b-43a8-9e4e-acc013ae8efe
if files_ready
	@bind b_slider PlutoUI.Slider(axes(phantom, 4), ; default=div(size(phantom, 4), 2), show_value=true)
end

# ╔═╡ 32292190-1124-4087-b728-8f998e3c3814
let
	if files_ready
		half_slice = good_slices[div(length(good_slices), 2)]
		f = Figure()
		ax = CairoMakie.Axis(f[1, 1])
		heatmap!(phantom[:, :, half_slice, b_slider], colormap=:grays)
		f
	end
end

# ╔═╡ 15681a0d-a217-42af-be91-6edeff37dfaa
if files_ready
	num_static_range_low = parse(Int, static_ranges[1])
	num_static_range_high = parse(Int, static_ranges[2])
	static_range = num_static_range_low:num_static_range_high
end;

# ╔═╡ c752398a-39ac-4dc3-a7db-bd19ee357075
if good_slices_files_ready
	good_slices_matrix = Int.(hcat(zeros(size(phantom, 3)), collect(axes(phantom, 3))))
	for i in good_slices
		idx = findall(x -> x == i, good_slices_matrix[:, 2])
		good_slices_matrix[idx..., 1] = 1
	end
end;

# ╔═╡ d0c6dc6d-b85f-4f76-a478-02fcd9484344
md"""
# Calculate Average Static Phantom
"""

# ╔═╡ 4a485292-f875-44c4-b940-8f2714f6d26f
if good_slices_files_ready
	good_slices_range = first(good_slices):last(good_slices)
end;

# ╔═╡ 886c9748-b423-4d68-acb4-2b32c65ebc1d
if good_slices_files_ready
	phantom_ok = phantom[:, :, good_slices_range, static_range]
	phantom_ok = Float64.(convert(Array, phantom))
end;

# ╔═╡ d75e495c-bf4e-4608-bd7f-357d3fe1023b
if good_slices_files_ready
	sph = staticphantom(phantom_ok, good_slices_matrix; staticslices=static_range)
end;

# ╔═╡ ad5f052a-8421-494a-96cd-2e5ad7ab8b2b
if good_slices_files_ready
	@bind c_slider PlutoUI.Slider(good_slices, ; default=good_slices[div(length(good_slices), 2)], show_value=true)
end

# ╔═╡ fc87815b-54d1-4f69-ac8d-b0fbeab7f53d
if good_slices_files_ready
	@bind d_slider PlutoUI.Slider(axes(phantom, 4), ; default=div(size(phantom, 4), 2), show_value=true)
end

# ╔═╡ f57cb424-9dd2-4432-8485-034ded569f13
if good_slices_files_ready
	ave = BDTools.genimg(sph.data[:, :, c_slider])
end;

# ╔═╡ e570adef-e2d1-4080-86e8-4ac57ad8a6f0
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

# ╔═╡ 5e364415-8ab9-4f8d-a775-03d45748b249
md"""
# Create Mask for B-field Correction
"""

# ╔═╡ 056f3868-9a21-4c68-9f51-a9ed2d662e46
if good_slices_files_ready
	@bind c_slider2 PlutoUI.Slider(good_slices, ; default=8, show_value=true)
end

# ╔═╡ 13b34063-4fea-4044-9648-7d72fd90ed2d
if good_slices_files_ready
	msk = BDTools.segment3(sph.data[:, :, c_slider2])
end;

# ╔═╡ e512474b-a648-416a-a52f-19b0e52fbd17
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

# ╔═╡ 659ec1a1-356c-4742-bd63-0ebaa3df5b96
md"""
# Run B-field Correction on Static Image
"""

# ╔═╡ 01455019-c0bd-43b4-9157-c757901e18dc
md"""
# Correct 4D Phantom w/ B-field
"""

# ╔═╡ Cell order:
# ╠═866b498e-52cc-461a-90dc-bfd6d53dd80d
# ╠═e7a428ce-0489-43c3-8c5a-bae818f0ca03
# ╟─dc6717ba-25fb-4f7d-933a-18dc69fea34d
# ╟─d2e0accd-2395-4115-8842-e9176a0a132e
# ╟─d90a11ce-52fd-48e4-9cb1-755bc2b29e51
# ╠═835f1748-0940-4a39-abb6-afa6ef8c4b90
# ╠═19b12720-4bd9-4790-84d0-9cf660d8ed70
# ╟─7f2148e2-8649-4fb6-a50b-3dc54bca7505
# ╟─8eb754de-37b7-45fb-a7fc-c14c11e0216f
# ╠═7eacbaef-eae0-426a-be36-9c00a3b09d1b
# ╟─6a8117e0-e450-46d7-897f-0503d71f06af
# ╟─49557d91-e4de-486b-99ed-3d564c7b7960
# ╟─04c7cf73-fa75-45e1-aafe-4ca658706289
# ╟─f11be125-facc-44ff-8d00-8cd748d6d110
# ╟─877c4ec3-5c00-496a-b4e0-d09fc46fd207
# ╟─8724296c-6118-4c0f-bea4-3173222a40cf
# ╟─1d1fa36d-774b-43a8-9e4e-acc013ae8efe
# ╟─32292190-1124-4087-b728-8f998e3c3814
# ╠═15681a0d-a217-42af-be91-6edeff37dfaa
# ╠═c752398a-39ac-4dc3-a7db-bd19ee357075
# ╟─d0c6dc6d-b85f-4f76-a478-02fcd9484344
# ╠═4a485292-f875-44c4-b940-8f2714f6d26f
# ╠═886c9748-b423-4d68-acb4-2b32c65ebc1d
# ╠═d75e495c-bf4e-4608-bd7f-357d3fe1023b
# ╟─ad5f052a-8421-494a-96cd-2e5ad7ab8b2b
# ╟─fc87815b-54d1-4f69-ac8d-b0fbeab7f53d
# ╠═f57cb424-9dd2-4432-8485-034ded569f13
# ╟─e570adef-e2d1-4080-86e8-4ac57ad8a6f0
# ╟─5e364415-8ab9-4f8d-a775-03d45748b249
# ╟─056f3868-9a21-4c68-9f51-a9ed2d662e46
# ╠═13b34063-4fea-4044-9648-7d72fd90ed2d
# ╟─e512474b-a648-416a-a52f-19b0e52fbd17
# ╟─659ec1a1-356c-4742-bd63-0ebaa3df5b96
# ╟─01455019-c0bd-43b4-9157-c757901e18dc
