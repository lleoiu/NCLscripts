load "$NCARG_ROOT/lib/ncarg/nclex/gsun/gsn_code.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_csm.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/contributed.ncl"

begin

nyears = 40

secdays = 86400.0

Experiments = (/"CESMtopof19","CESMnoRT2f19","CESMnoRf19","CESMnoT2f19"/);,"CESMnotopof19"
print(Experiments)

nexps = dimsizes(Experiments)

diro = "/home/disk/rachel/CESM_outfiles/" + Experiments(0) + "/atm/hist/"
filo = "DJF" + tostring(nyears) + "_mean_pl_" + Experiments(0) + ".cam2.h0.nc"
cdf_file = addfile(diro + filo, "r")

levs_mean = cdf_file->lev_p

; Find 700hpa levels
levsizes = dimsizes(levs_mean)
nlevs = levsizes(0)

nlev_700 = -1

do nl = 0,nlevs-1
	if levs_mean(nl) .EQ. 700 then
		nlev_700 = nl
	end if
end do

if (nlev_700 .LT. 0) then
	print("didnt find a level")
	exit
end if

ndims = dimsizes(cdf_file->U)

OMEGA700 = new((/nexps,ndims(2),ndims(3)/),typeof(cdf_file->OMEGA))
PHIS = new((/nexps,ndims(2),ndims(3)/),typeof(cdf_file->OMEGA))

OMEGA700(0,:,:) = cdf_file->OMEGA(0,nlev_700,:,:)

lats = cdf_file->lat
lons = cdf_file->lon

delete(cdf_file)
diro = "/home/disk/rachel/CESM_outfiles/" + Experiments(0) + "/atm/hist/"
filo = "DJF" + tostring(nyears) + "_mean_" + Experiments(0) + ".cam2.h0.nc"
cdf_file = addfile(diro + filo, "r")

lats = cdf_file->lat
lons = cdf_file->lon

PHIS(0,:,:) = cdf_file->PHIS(0,:,:) / 9.8
delete(cdf_file)
do iexp = 1,nexps-1

	diro = "/home/disk/rachel/CESM_outfiles/" + Experiments(iexp) + "/atm/hist/"
	filo = "DJF" + tostring(nyears) + "_mean_pl_" + Experiments(iexp) + ".cam2.h0.nc"
	cdf_file = addfile(diro + filo, "r")

	levs_mean = cdf_file->lev_p

; Check levs

	if levs_mean(nlev_700) .NE. 700 then
		print(levs_mean(nlev_700))
		print("should be 700!")
		exit
	end if

	OMEGA700(iexp,:,:) = cdf_file->OMEGA(0,nlev_700,:,:)
	
	delete(cdf_file)
	diro = "/home/disk/rachel/CESM_outfiles/" + Experiments(iexp) + "/atm/hist/"
	filo = "DJF" + tostring(nyears) + "_mean_" + Experiments(iexp) + ".cam2.h0.nc"
	cdf_file = addfile(diro + filo, "r")
	PHIS(iexp,:,:) = cdf_file->PHIS(0,:,:) / 9.8
	delete(cdf_file)

end do

toplot700 = new((/5,ndims(2),ndims(3)/),typeof(OMEGA700))
toplot700(0,:,:) = OMEGA700(0,:,:)
toplot700(1,:,:) =  OMEGA700(0,:,:) - OMEGA700(1,:,:)
toplot700(2,:,:) =  OMEGA700(0,:,:) - OMEGA700(2,:,:)
toplot700(3,:,:) =  OMEGA700(0,:,:) - OMEGA700(3,:,:)
toplot700(4,:,:) =  toplot700(1,:,:) - toplot700(2,:,:) - toplot700(3,:,:)

toplot3 = new((/5,ndims(2),ndims(3)/),typeof(PHIS))
toplot3(0,:,:) = PHIS(0,:,:)
toplot3(1,:,:) =  PHIS(0,:,:) - PHIS(1,:,:)
toplot3(2,:,:) =  PHIS(0,:,:) - PHIS(2,:,:)
toplot3(3,:,:) =  PHIS(0,:,:) - PHIS(3,:,:)
toplot3(4,:,:) =  toplot3(1,:,:) - toplot3(2,:,:) - toplot3(3,:,:)


titles = new((/5/),typeof(Experiments))
titles(0) = Experiments(0)
titles(1) =  "(topo - noRT2)"
titles(2) =  "(topo - noR)" 
titles(3) =  "(topo - noT2)" 
titles(4) =  titles(1) + "-" + titles(2) + "-" + titles(3)

toplot700!1 = "lat"
toplot700!2 = "lon"

toplot700&lat = lats
toplot700&lon = lons

toplot700&lat@units="degree_north"
toplot700&lon@units="degree_east"

copy_VarCoords(toplot700,toplot3)


; plot
; plot one = 700mb

  wks   = gsn_open_wks ("eps","Figures/OMEGA_700mb_40yrs_RT2")                  ; open workstation

  gsn_define_colormap(wks,"BlAqGrYeOrRe")         ; choose colormap
  plot = new(5,graphic)                          ; create a plot array

  res                      = True                 ; plot mods desired
   res@gsnDraw  = False                          ; don't draw
  res@gsnFrame = False                          ; don't advance frame
  res@cnFillOn             = True                 ; turn on color fill
  res@cnLinesOn            = False                ; turn off contour lines
  res@gsnSpreadColors      = True                 ; use full colormap
  res@gsnSpreadColorStart  = 10                   ; start at color 10
  res@gsnSpreadColorEnd    = 96                   ; end at color 96
  res@gsnAddCyclic         = True                 ; add cyclic point
  res@gsnCenterString         = "mean OMEGA at 700mb,ms:S:-1:N:, " + titles(0)              ; add common title
  res@mpMinLatF = 0.0
  res@mpMaxLatF = 90.0

  res@lbOrientation   = "Vertical"                ; vertical label bar

  res@cnLevelSelectionMode = "ManualLevels"	; manually set the contour levels with the following 3 resources
  res@cnMinLevelValF  = -0.2			; set the minimum contour level
  res@cnMaxLevelValF  = 0.2			; set the maximum contour level
  res@cnLevelSpacingF       = 0.05      ; contour spacing

  plot(0) = gsn_csm_contour_map_ce(wks,toplot700(0,:,:),res) ;
  res@gsnCenterString         = titles(1)

  res@cnMinLevelValF  = -0.05			; set the minimum contour level
  res@cnMaxLevelValF  = 0.05			; set the maximum contour level
  res@cnLevelSpacingF       = 0.01      ; contour spacing

  plot(1) = gsn_csm_contour_map_ce(wks,toplot700(1,:,:),res) ;

  res@gsnCenterString         = titles(2)
  plot(2) = gsn_csm_contour_map_ce(wks,toplot700(2,:,:),res) ;

  res@gsnCenterString         = titles(3)
  plot(3) = gsn_csm_contour_map_ce(wks,toplot700(3,:,:),res) ;

  res@cnMinLevelValF  = -0.025			; set the minimum contour level
  res@cnMaxLevelValF  = 0.025			; set the maximum contour level
  res@cnLevelSpacingF       = 0.005      ; contour spacing
  res@gsnCenterString         = titles(4)
  plot(4) = gsn_csm_contour_map_ce(wks,toplot700(4,:,:),res) ;

  resOv = True
  resOv@gsnDraw = False                        ; do not draw the plot
  resOv@gsnFrame = False                       ; do not advance the frame
  resOv@cnLevelSelectionMode = "ExplicitLevels" ; use explicit levels
  resOv@cnLevels = (/1000.0,2000.0/)              ; set the contour levels
  resOv@gsnContourPosLineDashPattern = 1 	; sets negative contours to dash pattern 1
  resOv@cnLineLabelsOn       = False
  resOv@cnConstFLabelOn = False

do pp = 0,4
	plot_ov = gsn_csm_contour(wks,toplot3(pp,:,:),resOv)
	overlay(plot(pp),plot_ov)
end do

  resP                  = True                   ; modify the panel plot
  resP@gsnFrame         = False                  ; don't advance panel plot
  resP@gsnPanelBottom   = 0.05                   ; add space at bottom
  resP@gsnPaperOrientation = "landscape"          

      resP@gsnDraw = False                           ; draw later, in maximize mode
      panelid1 = gsn_panel_return(wks,plot,(/5,1/),resP) 

  gsn_panel(wks,plot,(/5,1/),resP)               ; now draw as one plot

      mres = True
      maximize_output(wks,mres)

end