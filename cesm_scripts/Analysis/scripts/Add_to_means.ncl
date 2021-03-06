load "$NCARG_ROOT/lib/ncarg/nclex/gsun/gsn_code.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_csm.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/contributed.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/shea_util.ncl"
begin

MET = getenv("NCL_Mtrans") ; Flag to calculate meridional potential energy transport, which isn't normally in the output files.
if (MET .EQ. 1) then
	print("Calculating all meridional transport terms")
end if
Direc = getenv("NCL_ARG_1")
nexps = toint(getenv("NCL_ARG_2"))
Experiments = new(nexps,"string")

g = 9.81
cp = 1004.0
lp = 2501000.0

do ne = 0,nexps-1
	Experiments(ne) = getenv("NCL_ARG_" + tostring(3+ne))
end do

startyr = toint(getenv("NCL_ARG_" + tostring(3+nexps)))
endyr = toint(getenv("NCL_ARG_" + tostring(4+nexps)))
secs = getenv("NCL_ARG_" + tostring(5+nexps))

dirstr = getenv("NCL_dirstr")

nyears = endyr-startyr+1

print(startyr*1)
print(endyr*1)


nexps2 = dimsizes(Experiments)
if(nexps2 .NE. nexps)
	print(nexp2)
	print(nexps)
	exit
end if

do exps = 0,nexps-1

	Experiment = Experiments(exps)
	print(Experiment)

	Dir = (Direc + Experiment + dirstr)

	system("mkdir " + Dir + "TempDir")
	system("mkdir " + Dir + "Extra")

	system("mv " + Dir + "/Extra/" + Experiment + ".cam2.h0.0* " + Dir + "/")

	system("mv " + Dir + Experiment + ".cam2.h0.*" + ".nc " + Dir + "TempDir/")

	if (isfilepresent(Dir + Experiment + ".cam2.h0." + startyr + "-01.nc")) then
		print("file not present" + Dir + Experiment + ".cam2.h0." + startyr + "-01.nc")
		exit
	end if
		
	do iy = startyr,endyr
		print(tostring(iy))
	        if iy .lt. 10 then
	                stringyear = "000" + tostring(iy)
		else 
			if iy .lt. 100 then
				stringyear = "00" + tostring(iy)
			else
				stringyear = "0" + tostring(iy)
			end if
		end if
		
		system("mv " + Dir + "TempDir/" + Experiment + ".cam2.h0." + stringyear + "-*" + ".nc " + Dir + "/")
       		do im = 1,12
       	        	if im .lt. 10 then
                	        stringmonth = "0" + tostring(im)
                	else
                	        stringmonth = tostring(im)
                	end if
	
	                if (.not.isfilepresent(Dir + Experiment + ".cam2.h0."+ stringyear + "-" + stringmonth + ".nc")) then
	                        print("file not present" + Dir + Experiment + ".cam2.h0."+ stringyear + "-" + stringmonth + ".nc")
	                        exit
	                end if

			;       Now for each month calculate Streamfunction, PV, theta

	
		        filename = (Dir + Experiment + ".cam2.h0."+ stringyear + "-" + stringmonth + ".nc")
		        cdf_file = addfile(filename,"w")
			lat = cdf_file->lat
			lon = cdf_file->lon
			time = cdf_file->time
			nlats = dimsizes(lat)
			nlons = dimsizes(lon)
			P0mb = 0.01*cdf_file->P0
			P0 = cdf_file->P0
			U = cdf_file->U
			V = cdf_file->V
			T = cdf_file->T
			Z3 = cdf_file->Z3
			Q = cdf_file->Q
			VQ = cdf_file->VQ	               
			VT = cdf_file->VT
			if MET .EQ. 1 then
				VZ = cdf_file->VZ
			end if 

			PHIS = cdf_file->PHIS
			
			hyam = cdf_file->hyam
			hybm = cdf_file->hybm
			hyai = cdf_file->hyai
			hybi = cdf_file->hybi

			PS = cdf_file->PS

	                levs = cdf_file->lev
	                nlevs = dimsizes(levs)
		
			if (levs(0) .LT. levs(nlevs-1)) then
				startlevs = 3
				endlevs = nlevs-1
				print(levs(startlevs))
				print(levs(endlevs))
			else
                                startlevs = 0
                                endlevs = nlevs-4 
                                print(levs(endlevs))  		
			end if

			SF = new(dimsizes(U), typeof(U))
			temp = new(dimsizes(U),typeof(U))
			uv2sfvpf(U,V,SF,temp)
			copy_VarMeta(U,SF)

			SFza = dim_rmvmean_Wrap(SF(time|:,lev|:,lat|:,lon|:))
			Z3za = dim_rmvmean_Wrap(Z3(time|:,lev|:,lat|:,lon|:))

			P = pres_hybrid_ccm(PS,P0,hyam,hybm)
			dP = dpres_hybrid_ccm(PS,P0,hyai,hybi)
			copy_VarCoords(U,P)
			copy_VarCoords(U,dP)
			gridtype = 1 	; 0 is gaussian, 1 is fixed

			newvars = pot_vort_hybrid(P,U,V,T,lat,gridtype,0)
			PV = newvars(:,:,:,:) 
			TH = pot_temp(P,T,0,False)
			
			; Calculate water vapour fluxes
			UQ = Q * U
			copy_VarMeta(VQ,UQ)
			UQ@long_name = "zonal water vapour flux"
			; Calculate vertically integrated moisture flux (also moisture for comparison to TMQ!
			; Using TCUQ = 1/g integral(qu)dp) from lower to upper levels
			; Calculate on hybrid levels - no interpolation below ground

			TCQ = vertint(Q(:,startlevs:endlevs,:,:),dP(:,startlevs:endlevs,:,:),1.0/g,"Total column moisture from wgt_vertical_int","kg/m2",1)	
                        TCUQ = vertint(UQ(:,startlevs:endlevs,:,:),dP(:,startlevs:endlevs,:,:),1.0/g,"Total zonal moisture flux from wgt_vertical_int","kg/ms",1)
                        TCVQ = vertint(VQ(:,startlevs:endlevs,:,:),dP(:,startlevs:endlevs,:,:),1.0/g,"Total meridional moisture flux from wgt_vertical_int","kg/ms",1)
		
			; Calculate divergences
			Udiv = uv2dvF_Wrap(U,V)
			QUdiv = uv2dvF_Wrap(UQ,VQ)
			TCQUdiv = uv2dvF_Wrap(TCUQ,TCVQ)
			QUdiv@long_name = "water vapour flux divergence from uv2dvF_Wrap(UQ,VQ)"
                        TCQUdiv@long_name = "Total column water vapour flux divergence from uv2dvF_Wrap(UQ,VQ)"
			Udiv@long_name = "wind divergence from uv2dvF_Wrap(U,V)"
			; Calculate meridional transport: cpVT + g VZ + lp VQ
			TCcpVT = vertint(VT(:,startlevs:endlevs,:,:),dP(:,startlevs:endlevs,:,:),cp/g,"Total column meridional heat transport, cpVT/g from vertint","kgm3/s3",1)
			TClpVQ = vertint(VQ(:,startlevs:endlevs,:,:),dP(:,startlevs:endlevs,:,:),lp/g,"Total column meridional moist energy transport,lpVQ/g, from vertint","kgm3/s3",1)

			if MET .EQ. 1 then
				TCgVZ = vertint(VZ(:,startlevs:endlevs,:,:),dP(:,startlevs:endlevs,:,:),1,"Total column meridional potential energy transport,gVZ/g, from vertint","kgm3/s3",1)
			end if			

			filevardef(cdf_file,"TH",typeof(TH),getvardims(TH))
                        filevardef(cdf_file,"SF",typeof(SF),getvardims(SF))
                        filevardef(cdf_file,"SFza",typeof(SFza),getvardims(SFza))
                        filevardef(cdf_file,"PV",typeof(PV),getvardims(PV))
                        filevardef(cdf_file,"Z3za",typeof(Z3za),getvardims(Z3za))
                        filevardef(cdf_file,"UQ",typeof(UQ),getvardims(UQ))
                        filevardef(cdf_file,"Udiv",typeof(Udiv),getvardims(Udiv))
			filevardef(cdf_file,"QUdiv",typeof(QUdiv),getvardims(QUdiv))
                        filevardef(cdf_file,"TCQ",typeof(TCQ),(/"time","lat","lon"/)) ;getvardims(TCQ))
                        filevardef(cdf_file,"TCUQ",typeof(TCUQ),getvardims(TCUQ))
                        filevardef(cdf_file,"TCVQ",typeof(TCVQ),getvardims(TCVQ))
                        filevardef(cdf_file,"TCQUdiv",typeof(TCQUdiv),getvardims(TCQUdiv))
			filevardef(cdf_file,"dP",typeof(dP),getvardims(dP))
			

                        filevardef(cdf_file,"TCcpVT",typeof(TCcpVT),getvardims(TCcpVT))
                        filevardef(cdf_file,"TClpVQ",typeof(TClpVQ),getvardims(TClpVQ))
			if MET .EQ. 1 then
				filevardef(cdf_file,"TCgVZ",typeof(TCgVZ),getvardims(TCgVZ))
			end if

			cdf_file->dP = dP
			cdf_file->TH = TH
			cdf_file->SF = SF
			cdf_file->SFza = SFza
			cdf_file->PV = PV
                        cdf_file->Z3za = Z3za
			cdf_file->UQ = UQ
			cdf_file->Udiv = Udiv
			cdf_file->QUdiv = QUdiv
                        cdf_file->TCQ = TCQ
                        cdf_file->TCUQ = TCUQ
                        cdf_file->TCVQ = TCVQ
                        cdf_file->TCQUdiv = TCQUdiv

			cdf_file->TCcpVT = TCcpVT
			cdf_file->TClpVQ = TClpVQ
			
			if MET .EQ. 1 then
				cdf_file->TCgVZ = TCgVZ
			end if

			delete(cdf_file)


	        end do
	end do
	
	system("ncra -O " + Dir + Experiment + ".cam2.h0.*-12.nc " + Dir + Experiment + ".cam2.h0.*-01.nc " + Dir + Experiment + ".cam2.h0.*-02.nc " + Dir + "DJF" + tostring(startyr) + "_" + tostring(nyears) + "_mean_" + Experiment + ".cam2.h0.nc")
	
	system("ncra -O " + Dir + Experiment + ".cam2.h0.*-03.nc " + Dir + Experiment + ".cam2.h0.*-04.nc " + Dir + Experiment + ".cam2.h0.*-05.nc " + Dir + "MAM" + tostring(startyr) + "_" + tostring(nyears) + "_mean_" + Experiment + ".cam2.h0.nc")
	
	system("ncra -O " + Dir + Experiment + ".cam2.h0.*-06.nc " + Dir + Experiment + ".cam2.h0.*-07.nc " + Dir + Experiment + ".cam2.h0.*-08.nc " + Dir + "JJA" + tostring(startyr) + "_" + tostring(nyears) + "_mean_" + Experiment + ".cam2.h0.nc")
	
	system("ncra -O " + Dir + Experiment + ".cam2.h0.*-09.nc " + Dir + Experiment + ".cam2.h0.*-10.nc " + Dir + Experiment + ".cam2.h0.*-11.nc " + Dir + "SON" + tostring(startyr) + "_" + tostring(nyears) + "_mean_" + Experiment + ".cam2.h0.nc")

;        system("ncra -O " + Dir + Experiment + ".cam2.h0.*-07.nc " + Dir + Experiment + ".cam2.h0.*-08.nc " + Dir + Experiment + ".cam2.h0.*-09.nc " + Dir + "JAS" + tostring(startyr) + "_" + tostring(nyears) + "_mean_" + Experiment + ".cam2.h0.nc")

	system("ncra -O " + Dir + Experiment + ".cam2.h0.*.nc " + Dir + "Annual" + tostring(startyr) + "_" + tostring(nyears) + "_mean_" + Experiment + ".cam2.h0.nc")

	system("mv " + Dir + "TempDir/*.nc " + Dir + "/")

	print("finished with " + Experiment + " from " + tostring(startyr) + " to " + tostring(endyr))

end do

end
