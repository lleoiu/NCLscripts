load "$NCARG_ROOT/lib/ncarg/nclex/gsun/gsn_code.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_csm.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/contributed.ncl"

; Based on NOAA NCL script at http://www.esrl.noaa.gov/psd/data/epflux/epflux.2010.ncl
; See also: http://www.esrl.noaa.gov/psd/data/epflux/img/EP_Flux_Calculation_and_Display.pdf
; Follows derivation of http://journals.ametsoc.org/doi/pdf/10.1175/1520-0469%281980%29037%3C2600%3AEPCSFT%3E2.0.CO%3B2
; Calculated EP fluxes from climatological (seasonal) mean
; produces Quasi-geostrophic Eliassen-Palm  Fluxes in spherical coordinates
; Plots the EP Flux vectors in a latitude-log(pressure) coordinate
; plot the divergence of EP-Flux

begin

; Get experiment names

print("Calc EP fluxes")
Direc = getenv("NCL_ARG_1")
nexps = toint(getenv("NCL_ARG_2"))
Experiments = new(nexps,"string")

do ne = 0,nexps-1
        Experiments(ne) = getenv("NCL_ARG_" + tostring(3+ne))
end do

startyr = toint(getenv("NCL_ARG_" + tostring(3+nexps)))
endyr = toint(getenv("NCL_ARG_" + tostring(4+nexps)))
secs = getenv("NCL_ARG_" + tostring(5+nexps))

nyears = endyr-startyr+1

lonstart = toint(getenv("NCL_ARG_lonstart"))
lonend = toint(getenv("NCL_ARG_lonend"))

timespan = "DJF"

a = 6.37122e06	; radius of Earth
PI = 3.14159265358979

cp = 1.00464e3
Rd = 287.0
kappa = (Rd/cp)
omega =  7.2921e-5
g = 9.80616

dimsexps = dimsizes(Experiments)
nexps = dimsexps(0)

do exps = 0,nexps-1
	Experiment = Experiments(exps)
	Dir = (Direc + Experiment + "/atm/hist/")
	print(Experiment)


	filename = Dir + timespan + tostring(startyr) + "_" + tostring(nyears) + "_mean_Xpl_" + Experiment + ".cam2.h0.nc"
	; open file with seasonal averages
	cdf_file = addfile(filename,"r")

	; get pressure levels

	level = cdf_file->lev_p		; in hpa, or mb
	level!0="lev_p"
	levsizes = dimsizes(level)
	nlevels = filevardimsizes(cdf_file,"lev_p")
	nlat = filevardimsizes(cdf_file,"lat")
	nlon = filevardimsizes(cdf_file,"lon")

	lat = tofloat(cdf_file->lat)
	lat!0="lat"
	lon = tofloat(cdf_file->lon)
	lon!0="lon"

	; find lonstart and lonend
		do ilon = 0,nlons-2
			if (lon(ilon) < lonstart .AND. lon(ilon+1) > lonstart)
				idxlonstart = ilon
				break
			end if
		end do
                do ilon = 0,nlons-2
                        if (lon(ilon) < lonend .AND. lon(ilon+1) > lonend)
                                idxlonend = ilon
                                break
                        end if
                end do


	U = cdf_file->U(:,:,:,idxlonstart:idxlonend)
	V = cdf_file->V(:,:,:,idxlonstart:idxlonend)
	T = cdf_file->T(:,:,:,idxlonstart:idxlonend)

	print("dim of U")
	print(dimsizes(U))


	; Calculate potential temperature
	THETA = T
	THETA = T * (conform(T,level,1)/1000.0)^(-1.0 * kappa)
	THETAzm = dim_avg_Wrap(THETA)
	; Calculate d(THETA)/dp from vertical finite differences in log-pressure coordinates
	; noting that dT/dp = (1/p) * dT/d(lnp)
	loglevel = log(level)

	THETAp = center_finite_diff_n(THETAzm(time|:,lev_p|:,lat|:),loglevel,False,0,1) ; derivative in log coords doesn't care whether in Pa or in mb.
	; named subscripting reorders the dimensions
	THETAp = THETAp / conform(THETAp,100.0 * level,1) ; converts "level" to pascals from millibars while dividing by pressure.
        copy_VarMeta(THETAzm,THETAp)

	; za stands for zonal anomaly
	THETAp!2="lat"
	; zm stands for zonal mean

	Uza = dim_rmvmean_Wrap(U(time|:,lev_p|:,lat|:,lon|:))	; removes mean of rightmost dimension
	Vza = dim_rmvmean_Wrap(V(time|:,lev_p|:,lat|:,lon|:))	; removes mean of rightmost dimension
	THETAza = dim_rmvmean_Wrap(THETA(time|:,lev_p|:,lat|:,lon|:))

	UV = Uza * Vza
	copy_VarMeta(Uza,UV)
	UVzm = dim_avg_n_Wrap(UV(time|:,lev_p|:,lat|:,lon|:),3)	; averages over longitude dimension
	UVzmtm = dim_avg_n_Wrap(UVzm(time|:,lev_p|:,lat|:),0)	; average over time dimension

	VTHETA = Vza * THETAza
	copy_VarCoords(Vza,VTHETA)
	VTHETAzm = dim_avg_Wrap(VTHETA)
	VTHETAzmtm = dim_avg_n_Wrap(VTHETAzm(time|:,lev_p|:,lat|:),0)	; average over time dimension

	THETAptm = dim_avg_n_Wrap(THETAp(time|:,lev_p|:,lat|:),0)	; time mean of THETAp

	phi = lat*PI/180.0	; Get latitude in radians
	cphi = cos(phi)
	acphi = a * cos(phi)
	asphi = a * sin(phi)
	f = 2*omega*sin(phi)

	latfac  = acphi	; scale factor no longer includes extra cos(phi) for graphical display of arrows
	
	Fphi = -UVzmtm*conform(UVzmtm,latfac,1)
	Fphicphi = Fphi * conform(Fphi,cphi,1)
	Fp = conform(VTHETAzmtm,f*acphi,1) * VTHETAzmtm/THETAptm
	copy_VarMeta(UVzmtm,Fphi)
	copy_VarMeta(VTHETAzmtm,Fp)


; Compute divergence of EP fluxes
; take derivative with respect to latitude using 1/[a cos(phi)] d/dphi [cos(phi)*X] = d/d[asin(phi)] (cos(phi) * X)

	Fphicphi = Fphi * conform(Fphi,acphi,1)
	copy_VarMeta(Fphi,Fphicphi)
	EPdiv1 = center_finite_diff_n(Fphicphi(lev_p|:,lat|:),asphi,False,0,1)

; take derivate with respect to pressure
; Pressure in pascals
	EPdiv2 = center_finite_diff_n(Fp(lev_p|:,lat|:),100.0 * level,False,0,0)	; Convert to pa from hpa
; Add together derivative components
	EPdiv = EPdiv1 + EPdiv2
	copy_VarMeta(Fp,EPdiv)

        Fp&lat = lat
        Fp&lev_p = level

        copy_VarMeta(Fp,EPdiv)
        copy_VarMeta(Fp,Fphi)

; Put onto equally space log-pressure levels

	level_int = 10^fspan(1,3,15)   ; interpolation targets
	level_int!0 = "lev_int"

	nlev_int = dimsizes(level_int)
	linlog=2                       ; Option to int2p that gives log-interpolation with no extrapolation
	Fp_int = int2p_n_Wrap(level,Fp(lev_p|:,lat|:),level_int,linlog,0)
	Fphi_int = int2p_n_Wrap(level,Fphi(lev_p|:,lat|:),level_int,linlog,0)
	EPdiv_int = int2p_n_Wrap(level,EPdiv(lev_p|:,lat|:),level_int,linlog,0)

	Fp_int!0 = "lev_int"
	Fp_int&lev_int = level_int
        Fphi_int!0 = "lev_int"
        Fphi_int&lev_int = level_int
        EPdiv_int!0 = "lev_int"
        EPdiv_int&lev_int = level_int


; Compute acceleration from divF

	dudt = 86400.0 * EPdiv/conform(EPdiv,acphi,1);
	dudt@long_name = "acceleration from EP flux divergence"
	dudt@units = "m/s2"
	copy_VarCoords(EPdiv,dudt)

        dudt_int = 86400.0 * EPdiv_int/conform(EPdiv_int,acphi,1);
        dudt_int@long_name = "acceleration from EP flux divergence"
        dudt_int@units = "m/s2"
        copy_VarCoords(EPdiv_int,dudt_int)
	
;-----------------------------------------------------------------------

	filo = "EPfluxes_" + timespan + tostring(startyr) + "_" + tostring(nyears) + "_orig_" + Experiment + ".cam2.h0.nc"
	system("/bin/rm -f " + Dir + filo)
	fout_std = addfile(Dir + filo, "c")

	setfileoption(fout_std,"DefineMode",True)

;set attributes of output file
	fAtt = True
	fAtt@creation_date = systemfunc("date")
	fileattdef(fout_std,fAtt)
	
;set dimensions of output file
	dimNames = (/"lat","lev_p","lev_int"/)
	dimSizes = (/nlat,nlevels,nlev_int/)
	dimUnlim = (/False,False,False/)
	filedimdef(fout_std,dimNames,dimSizes,dimUnlim)

	filevardef(fout_std,"lat",typeof(lat),getvardims(lat))
	filevardef(fout_std,"level",typeof(level),getvardims(level))
        filevardef(fout_std,"level_int",typeof(level_int),getvardims(level_int))

	
	filevardef(fout_std,"Fphi",typeof(Fphi),getvardims(Fphi))
        filevardef(fout_std,"Fp",typeof(Fp),getvardims(Fp))
        filevardef(fout_std,"EPdiv",typeof(EPdiv),getvardims(EPdiv))
	filevardef(fout_std,"dudt",typeof(dudt),getvardims(dudt))

        filevardef(fout_std,"Fphi_int",typeof(Fphi_int),getvardims(Fphi_int))
        filevardef(fout_std,"Fp_int",typeof(Fp_int),getvardims(Fp_int))
        filevardef(fout_std,"EPdiv_int",typeof(EPdiv_int),getvardims(EPdiv_int))
        filevardef(fout_std,"dudt_int",typeof(dudt_int),getvardims(dudt_int))

	fout_std->lat = (/lat/)
	fout_std->level = level
	fout_std->Fphi = Fphi
	fout_std->Fp = Fp
	fout_std->EPdiv = EPdiv
	fout_std->dudt = dudt

        fout_std->level_int = level_int
        fout_std->Fphi_int = Fphi_int
        fout_std->Fp_int = Fp_int
        fout_std->EPdiv_int = EPdiv_int
        fout_std->dudt_int = dudt_int

	print("printed it")

end do

end
