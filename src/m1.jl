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
	Pkg.add("CondaPkg")
	Pkg.add("PythonCall")
	Pkg.add(url="https://github.com/hstrey/BDTools.jl")
	Pkg.add("CairoMakie")
	Pkg.add("NIfTI")
	Pkg.add("PlutoUI")
	Pkg.add("CSV")
	Pkg.add("DataFrames")

	using CondaPkg; CondaPkg.add("SimpleITK")
	using PythonCall
	using BDTools
	using CairoMakie
	using PlutoUI
	using NIfTI
	using CSV
	using DataFrames
	using Statistics
end

# ╔═╡ 90b6279b-7595-43de-b3f7-10ffdbeabf58
sitk = pyimport("SimpleITK")

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
			md""" $(logs): $(@bind log_file TextField(60; default="https://www.dropbox.com/s/y2hyz2devw30s5x/log104.csv?dl=0"))""",
			md""" $(acqs): $(@bind acq_file TextField(60; default="https://www.dropbox.com/s/qu75ggnbc2rsji5/acq_times_104.csv?dl=0"))""",
			md""" $(phtm): $(@bind nifti_file TextField(60 ; default="https://www.dropbox.com/s/hikpi7t89mwbb4w/104.nii?dl=0"))"""
		]
		
		md"""
		#### Upload Files
		Provide URLs or file paths to the necessary files. If running locally, file paths are expected. If running on the web, provide URL links. We recommend DropBox, as Google Drive will likely not work.
		
		Ensure log and acquisition files are in `.csv` format & phantom file is in `.nii` or `.nii.gz` format. Then click submit
		$(inputs)
		"""
	end
end

# ╔═╡ d2e0accd-2395-4115-8842-e9176a0a132e
confirm(upload_files("Upload Log File: ", "Upload Acquisition Times: ", "Upload Phantom Scan: "))

# ╔═╡ 19b12720-4bd9-4790-84d0-9cf660d8ed70
try
	global df_log = CSV.read(download(log_file), DataFrame)
	
	global df_acq = CSV.read(download(acq_file), DataFrame)
		
	global phantom = niread(download(nifti_file))
catch
	global df_log = CSV.read(log_file, DataFrame)
	
	global df_acq = CSV.read(acq_file, DataFrame)
		
	global phantom = niread(nifti_file)
end;

# ╔═╡ 3baf736e-6b98-4703-baf8-ecf856b515e2
size(phantom)[2:end]

# ╔═╡ b0e58a0a-c6a7-4e4d-8a14-efbfbf7251e9
phantom_header = phantom.header

# ╔═╡ 3dcddb92-6277-46d2-9e34-3863f0a60731
vsize = voxel_size(phantom.header) # mm

# ╔═╡ 7f2148e2-8649-4fb6-a50b-3dc54bca7505
md"""
# Identify Good Slices
"""

# ╔═╡ 6a8117e0-e450-46d7-897f-0503d71f06af
function good_slice_info(good_slices_first, good_slices_last)
	
	return PlutoUI.combine() do Child
		
		inputs = [
			md""" $(good_slices_first): $(
				Child(TextField(default=string(27)))
			)""",
			md""" $(good_slices_last): $(
				Child(TextField(default=string(44)))
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
@bind g_slices confirm(good_slice_info("First good slice: ", "Last good slice: "))

# ╔═╡ 7eacbaef-eae0-426a-be36-9c00a3b09d1b
good_slices_files_ready = g_slices[1] != "" && g_slices[2] != "" 

# ╔═╡ 49557d91-e4de-486b-99ed-3d564c7b7960
@bind good_slices_slider PlutoUI.Slider(axes(phantom, 3); default=div(size(phantom, 3), 2), show_value=true)

# ╔═╡ 04c7cf73-fa75-45e1-aafe-4ca658706289
heatmap(phantom.raw[:, :, good_slices_slider, 1], colormap=:grays)

# ╔═╡ 4a485292-f875-44c4-b940-8f2714f6d26f
if good_slices_files_ready
	good_slices_range = parse(Int, first(g_slices)):parse(Int, last(g_slices))
end;

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
@bind static_ranges confirm(static_slice_info("Starting static slice: ", "Ending static slice: "))

# ╔═╡ 1d1fa36d-774b-43a8-9e4e-acc013ae8efe
@bind b_slider PlutoUI.Slider(axes(phantom, 4); default=div(size(phantom, 4), 2), show_value=true)

# ╔═╡ 32292190-1124-4087-b728-8f998e3c3814
heatmap(phantom[:, :, div(size(phantom, 3), 2), b_slider], colormap=:grays)

# ╔═╡ 15681a0d-a217-42af-be91-6edeff37dfaa
begin
	num_static_range_low = parse(Int, static_ranges[1])
	num_static_range_high = parse(Int, static_ranges[2])
	static_range = num_static_range_low:num_static_range_high
end;

# ╔═╡ 886c9748-b423-4d68-acb4-2b32c65ebc1d
if good_slices_files_ready
	phantom_ok = phantom[:, :, good_slices_range, static_range]
	phantom_ok = Float64.(convert(Array, phantom_ok))
end;

# ╔═╡ de4e1b7c-2a70-499d-a375-87c8aaca0ad3
begin
	max_motion = findmax(df_log[!,"Tmot"])[1]
	slices_without_motion = df_acq[!,"Slice"][df_acq[!,"Time"] .> max_motion]
	slices_ok = sort(
		slices_without_motion[parse(Int, first(g_slices))-1 .<= slices_without_motion .<= parse(Int, last(g_slices))+1]
	)
	slices_wm = [x in slices_ok ? 1 : 0 for x in good_slices]
	slices_df = DataFrame(Dict(:slice => good_slices, :no_motion => slices_wm))
end

# ╔═╡ d0c6dc6d-b85f-4f76-a478-02fcd9484344
md"""
# Calculate Average Static Phantom
"""

# ╔═╡ d75e495c-bf4e-4608-bd7f-357d3fe1023b
if good_slices_files_ready
	sph = staticphantom(phantom_ok, Matrix(slices_df); staticslices=static_range)
end;

# ╔═╡ db78c6f2-5afe-4d12-b39f-f6b4286f2d17
phantom_header.dim = (length(size(sph.data)), size(sph.data)..., 1, 1, 1, 1)

# ╔═╡ 35e1fcca-f1e0-4b33-82c7-e0c1325464d0
if good_slices_files_ready
	@bind c_slider PlutoUI.Slider(axes(sph.data, 3) ; default=div(size(sph.data, 3), 2), show_value=true)
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
		heatmap!(phantom[:, :, slices_df[c_slider, 2], d_slider], colormap=:grays)
	
		ax = CairoMakie.Axis(
			f[1, 2],
			title="Average Static Image"
		)
		heatmap!(ave[:, :], colormap=:grays)
		f
	end
end

# ╔═╡ 4de55168-94c0-400e-a072-feb34a07fe2b
avg_static_phantom = sph.data;

# ╔═╡ a649bf25-f3e4-44b4-bb3e-266a456f2f21
begin
	tempdir = mktempdir()
	
	avg_static_phantom_path = joinpath(tempdir, "image.nii")
	niwrite(avg_static_phantom_path, NIVolume(phantom_header, avg_static_phantom))
end

# ╔═╡ 5e364415-8ab9-4f8d-a775-03d45748b249
md"""
# Create Mask for B-field Correction
"""

# ╔═╡ 056f3868-9a21-4c68-9f51-a9ed2d662e46
if good_slices_files_ready
	@bind c_slider2 PlutoUI.Slider(axes(sph.data, 3); show_value=true)
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

# ╔═╡ cb3c7d65-dcdf-48c9-a1fa-56ba71b327e5
begin
	msk3D = zeros(Int, size(sph.data)[1:2]..., length(good_slices))
	for i in axes(sph.data, 3)
		msk3D[:, :, i] = BDTools.segment3(sph.data[:, :, i]).image_indexmap
	end
	msk3D = parent(msk3D)
end;

# ╔═╡ 4168038a-7257-4082-8243-525175d12be0
begin
	binary_msk3D = zeros(Int, size(msk3D))
	idxs = findall(x -> x == 2 || x == 3, msk3D)
	for i in idxs
		binary_msk3D[i] = 1
	end
end;

# ╔═╡ 51a6b51f-55fd-442c-a6a0-5d9be970d300
begin
	mask_path = joinpath(tempdir, "mask.nii")
	niwrite(mask_path, NIVolume(phantom_header, binary_msk3D))
end

# ╔═╡ 692360cc-dcb0-456a-8234-f747ce371b1b
# heatmap(binary_msk3D[:, :, 2], colormap=:grays)

# ╔═╡ 659ec1a1-356c-4742-bd63-0ebaa3df5b96
md"""
# Run B-field Correction on Static Image
"""

# ╔═╡ 79bfc734-f19d-4d5b-a585-ef02bf2b0144
function bfield_correction(avg_phantom_path, mask_path; num_iterations, numberFittingLevels=4)
	inputImage = sitk.ReadImage(avg_phantom_path, sitk.sitkFloat32)
	image = inputImage
	
	maskImage = sitk.ReadImage(mask_path, sitk.sitkUInt8)
	
	corrector = sitk.N4BiasFieldCorrectionImageFilter()
	
	numberFittingLevels = pylist(numberFittingLevels)
	
	num_iterations = pylist(num_iterations)
	corrector.SetMaximumNumberOfIterations(num_iterations)

	corrected_image = corrector.Execute(image, maskImage)
    log_bias_field = corrector.GetLogBiasFieldAsImage(inputImage)

	tempdir = mktempdir()
	corrected_image_path = joinpath(tempdir, "corrected_image.nii")
	log_bias_field_path = joinpath(tempdir, "log_bias_field.nii")

	sitk.WriteImage(corrected_image, corrected_image_path)
	sitk.WriteImage(log_bias_field, log_bias_field_path)

	return (
		niread(avg_phantom_path),
		niread(mask_path),
		niread(log_bias_field_path),
		niread(corrected_image_path)
	)
end

# ╔═╡ bafa6302-6dbc-4b46-afc2-a414079a0472
input_image, mask, bfield, corrected_image = bfield_correction(avg_static_phantom_path, mask_path; num_iterations=4);

# ╔═╡ 958fc82b-454d-4f00-91c0-4c95bebe4117
@bind bfield_slider PlutoUI.Slider(axes(bfield, 3); show_value=true)

# ╔═╡ 87f3ccf9-4ee4-466e-a15c-f5000d6a3eca
let
	if good_slices_files_ready
		f = Figure(resolution=(1000, 700))
		ax = CairoMakie.Axis(
			f[1, 1],
			title="Average Static Phantom"
		)
		heatmap!(input_image[:, :, bfield_slider], colormap=:grays)
	
		ax = CairoMakie.Axis(
			f[1, 2],
			title="Corrected Average Static Phantom"
		)
		heatmap!(corrected_image[:, :, bfield_slider], colormap=:grays)
		f
	end
end

# ╔═╡ efb1f173-b7ef-4ce1-9d72-47fcda97da7d
let
	if good_slices_files_ready
		f = Figure(resolution=(1000, 700))
		ax = CairoMakie.Axis(
			f[1, 1],
			title="Difference"
		)
		heatmap!(corrected_image[:, :, bfield_slider] - input_image[:, :, bfield_slider])
	
		ax = CairoMakie.Axis(
			f[1, 2],
			title="B-Field"
		)
		heatmap!(bfield[:, :, bfield_slider], colormap=:grays)
		f
	end
end

# ╔═╡ 01455019-c0bd-43b4-9157-c757901e18dc
md"""
# Correct 4D Phantom w/ B-field
"""

# ╔═╡ 304923f3-fbe0-4ef6-852b-fab8f49fd43d
phantom_whole = phantom[:, :, good_slices_range, :];

# ╔═╡ 3042e311-40fb-40a0-a4f2-d641dfb07809
begin 
	bfc_image = zeros(size(phantom_whole))
	for i in axes(phantom_whole, 4)
		for j in axes(phantom_whole, 3)
			bfc_image[:,:,j,i] = phantom_whole[:, :, j, i] ./ bfield[:, :, j]
		end
	end
end

# ╔═╡ 5c7e141d-6a49-4341-a1a4-b3eefd6b5ea5
bfc_image

# ╔═╡ Cell order:
# ╠═866b498e-52cc-461a-90dc-bfd6d53dd80d
# ╠═90b6279b-7595-43de-b3f7-10ffdbeabf58
# ╠═e7a428ce-0489-43c3-8c5a-bae818f0ca03
# ╟─dc6717ba-25fb-4f7d-933a-18dc69fea34d
# ╟─d90a11ce-52fd-48e4-9cb1-755bc2b29e51
# ╟─d2e0accd-2395-4115-8842-e9176a0a132e
# ╠═19b12720-4bd9-4790-84d0-9cf660d8ed70
# ╠═3baf736e-6b98-4703-baf8-ecf856b515e2
# ╠═b0e58a0a-c6a7-4e4d-8a14-efbfbf7251e9
# ╠═3dcddb92-6277-46d2-9e34-3863f0a60731
# ╟─7f2148e2-8649-4fb6-a50b-3dc54bca7505
# ╟─6a8117e0-e450-46d7-897f-0503d71f06af
# ╟─8eb754de-37b7-45fb-a7fc-c14c11e0216f
# ╠═7eacbaef-eae0-426a-be36-9c00a3b09d1b
# ╟─49557d91-e4de-486b-99ed-3d564c7b7960
# ╟─04c7cf73-fa75-45e1-aafe-4ca658706289
# ╠═4a485292-f875-44c4-b940-8f2714f6d26f
# ╟─f11be125-facc-44ff-8d00-8cd748d6d110
# ╟─877c4ec3-5c00-496a-b4e0-d09fc46fd207
# ╟─8724296c-6118-4c0f-bea4-3173222a40cf
# ╟─1d1fa36d-774b-43a8-9e4e-acc013ae8efe
# ╟─32292190-1124-4087-b728-8f998e3c3814
# ╠═15681a0d-a217-42af-be91-6edeff37dfaa
# ╠═886c9748-b423-4d68-acb4-2b32c65ebc1d
# ╠═de4e1b7c-2a70-499d-a375-87c8aaca0ad3
# ╟─d0c6dc6d-b85f-4f76-a478-02fcd9484344
# ╠═d75e495c-bf4e-4608-bd7f-357d3fe1023b
# ╠═db78c6f2-5afe-4d12-b39f-f6b4286f2d17
# ╟─35e1fcca-f1e0-4b33-82c7-e0c1325464d0
# ╟─fc87815b-54d1-4f69-ac8d-b0fbeab7f53d
# ╟─f57cb424-9dd2-4432-8485-034ded569f13
# ╟─e570adef-e2d1-4080-86e8-4ac57ad8a6f0
# ╠═4de55168-94c0-400e-a072-feb34a07fe2b
# ╠═a649bf25-f3e4-44b4-bb3e-266a456f2f21
# ╟─5e364415-8ab9-4f8d-a775-03d45748b249
# ╟─056f3868-9a21-4c68-9f51-a9ed2d662e46
# ╠═13b34063-4fea-4044-9648-7d72fd90ed2d
# ╟─e512474b-a648-416a-a52f-19b0e52fbd17
# ╠═cb3c7d65-dcdf-48c9-a1fa-56ba71b327e5
# ╠═4168038a-7257-4082-8243-525175d12be0
# ╠═51a6b51f-55fd-442c-a6a0-5d9be970d300
# ╠═692360cc-dcb0-456a-8234-f747ce371b1b
# ╟─659ec1a1-356c-4742-bd63-0ebaa3df5b96
# ╠═79bfc734-f19d-4d5b-a585-ef02bf2b0144
# ╠═bafa6302-6dbc-4b46-afc2-a414079a0472
# ╟─958fc82b-454d-4f00-91c0-4c95bebe4117
# ╟─87f3ccf9-4ee4-466e-a15c-f5000d6a3eca
# ╟─efb1f173-b7ef-4ce1-9d72-47fcda97da7d
# ╟─01455019-c0bd-43b4-9157-c757901e18dc
# ╠═304923f3-fbe0-4ef6-852b-fab8f49fd43d
# ╠═3042e311-40fb-40a0-a4f2-d641dfb07809
# ╠═5c7e141d-6a49-4341-a1a4-b3eefd6b5ea5
