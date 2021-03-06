load "$NCARG_ROOT/lib/ncarg/nclex/gsun/gsn_code.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_csm.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/contributed.ncl"

begin

startnlon = 29
endnlon = 61
startnlat = 71
endnlat = 76

gpt_min = 490 ;50m
sgh_min = 30 ; roughness of flat russia/flat america
sgh30_min = 10; roughness of flat russia/flat america

file1 = "CESMSOM4topof19g16.cam2.h0.0169-12.nc"
file2 = "CESMSOM4topof19g16.cam2.r.0170-01-01-00000.nc"

diro = "/home/disk/eos4/rachel/inputdata/som/restart/noM/CESMSOM4topo/"

system("cp " + diro + file1 + " " + diro + "Orig_" + file1)
system("cp " + diro + file2 + " " + diro + "Orig_" + file2)

fileout1 = diro + file1
fileout2 = diro + file2

; create normal distrbution with 300 bins

nbins = 60

opt = True
opt@npts = nbins
nd = genNormalDist(1,1,opt)

nd = nd / sum(nd)

dims = dimsizes(nd)
print(dims)

ndcdf_f = new(dims,float)
ndcdf_f(0) = nd(0)

do nn = 1,dims-1
	ndcdf_f(nn) = ndcdf_f(nn-1) + nd(nn)
end do

ndcdf_d = new(dims,double)
ndcdf_d(0) = nd(0)

do nn = 1,dims-1
        ndcdf_d(nn) = ndcdf_d(nn-1) + nd(nn)
end do

;now take values at equal spacings:
spacing = (nbins/6)
weights_f = new(7,float)

weights_f(0) = ndcdf_f(spacing - 1)
weights_f(1) = ndcdf_f(2 * spacing - 1)
weights_f(2) = ndcdf_f(3 * spacing - 1)
weights_f(3) = ndcdf_f(4 * spacing - 1)
weights_f(4) = ndcdf_f(5 * spacing - 1)
weights_f(5) = 1.0

print(weights_f)

weights_d = new(7,double)

weights_d(0) = ndcdf_d(spacing - 1)
weights_d(1) = ndcdf_d(2 * spacing - 1)
weights_d(2) = ndcdf_d(3 * spacing - 1)
weights_d(3) = ndcdf_d(4 * spacing - 1)
weights_d(4) = ndcdf_d(5 * spacing - 1)
weights_d(5) = 1.0

filenamein = diro + file1

print("reading file in...")
  cdf_file = addfile(filenamein,"r")
print("file read in")

gpt = cdf_file->PHIS(0,:,:)
lm = cdf_file->LANDFRAC(0,:,:)

filenamein2 = diro + file2

print("reading file in...")
  cdf_file = addfile(filenamein2,"r")
print("file read in")

sgh = cdf_file->SGH
sgh30 = cdf_file->SGH30

print(dimsizes(sgh))

gpt_new = gpt
sgh_new = sgh
sgh30_new = sgh30

printVarSummary(sgh)

print(dimsizes(gpt))
dims1 = dimsizes(gpt)
numlats = dims1(0)
numlons = dims1(1)
print(numlats)
print(numlons)


;sponge region - southern edge
gwgt = 5
do ny = startnlat-5,startnlat
	gwgt2 = 5
	print("first 5")
	do nx = startnlon-5,startnlon
		f2 = (/weights_f(gwgt),weights_f(gwgt2)/)
		print(max(f2))
		printVarSummary(gpt)
		printVarSummary(f2)
		gpt_new(ny,nx) = max(f2) * gpt(ny,nx)

                f2_d = (/weights_d(gwgt),weights_d(gwgt2)/)
		sgh_new(ny,nx) = max(f2_d) * sgh(ny,nx)
		sgh30_new(ny,nx) = max(f2_d) * sgh30(ny,nx)

		gwgt2 = gwgt2 - 1
		if (lm(ny,nx) .gt. 0)
			g1 = (/min((/gpt_min,gpt(ny,nx)/)),gpt_new(ny,nx)/)
			gpt_new(ny,nx) = max(g1) * lm(ny,nx)
			g2 = (/min((/sgh_min,sgh(ny,nx)/)),sgh_new(ny,nx)/)
			sgh_new(ny,nx) = max(g2) * todouble(lm(ny,nx))
			g3 = (/min((/sgh30_min,sgh30(ny,nx)/)),sgh30_new(ny,nx)/)
			sgh30_new(ny,nx) = max(g3) * todouble(lm(ny,nx))	
		end if

	end do
	print("then")
	do nx = startnlon + 1,endnlon-1
		gpt_new(ny,nx) = weights_f(gwgt) * gpt(ny,nx)
		sgh_new(ny,nx) = weights_d(gwgt) * sgh(ny,nx)
		sgh30_new(ny,nx) = weights_d(gwgt) * sgh30(ny,nx)
		if (lm(ny,nx) .gt. 0)
			g1 = (/min((/gpt_min,gpt(ny,nx)/)),gpt_new(ny,nx)/)
			gpt_new(ny,nx) = max(g1) * lm(ny,nx)
			g2 = (/min((/sgh_min,sgh(ny,nx)/)),sgh_new(ny,nx)/)
			sgh_new(ny,nx) = max(g2) * todouble(lm(ny,nx))
			g3 = (/min((/sgh30_min,sgh30(ny,nx)/)),sgh30_new(ny,nx)/)
			sgh30_new(ny,nx) = max(g3) * todouble(lm(ny,nx))	
		end if
	end do

	gwgt2 = 0
	print("last 5")
	do nx = endnlon,endnlon + 5
		f2 = (/weights_f(gwgt),weights_f(gwgt2)/)
		print(max(f2))
		gpt_new(ny,nx) = max(f2) * gpt(ny,nx)
                f2_d = (/weights_d(gwgt),weights_d(gwgt2)/)
		sgh_new(ny,nx) = max(f2_d) * sgh(ny,nx)
		sgh30_new(ny,nx) = max(f2_d) * sgh30(ny,nx)
		gwgt2 = gwgt2 + 1
		if (lm(ny,nx) .gt. 0)
			g1 = (/min((/gpt_min,gpt(ny,nx)/)),gpt_new(ny,nx)/)
			gpt_new(ny,nx) = max(g1) * lm(ny,nx)
			g2 = (/min((/sgh_min,sgh(ny,nx)/)),sgh_new(ny,nx)/)
			sgh_new(ny,nx) = max(g2) * todouble(lm(ny,nx))
			g3 = (/min((/sgh30_min,sgh30(ny,nx)/)),sgh30_new(ny,nx)/)
			sgh30_new(ny,nx) = max(g3) * todouble(lm(ny,nx))
		end if
	end do

	gwgt = gwgt - 1

end do
;print(gwgt)

;sponge region - northern edge
gwgt = 0
do ny = endnlat,endnlat+5
	gwgt2 = 5
	do nx = startnlon-5,startnlon
		f2 = (/weights_f(gwgt),weights_f(gwgt2)/)
		gpt_new(ny,nx) = max(f2) * gpt(ny,nx)
                f2_d = (/weights_d(gwgt),weights_d(gwgt2)/)
		sgh_new(ny,nx) = max(f2_d) * sgh(ny,nx)
		sgh30_new(ny,nx) = max(f2_d) * sgh30(ny,nx)

		gwgt2 = gwgt2 - 1
		if (lm(ny,nx) .gt. 0)
			g1 = (/min((/gpt_min,gpt(ny,nx)/)),gpt_new(ny,nx)/)
			gpt_new(ny,nx) = max(g1) * lm(ny,nx)
			g2 = (/min((/sgh_min,sgh(ny,nx)/)),sgh_new(ny,nx)/)
			sgh_new(ny,nx) = max(g2) * todouble(lm(ny,nx))
			g3 = (/min((/sgh30_min,sgh30(ny,nx)/)),sgh30_new(ny,nx)/)
			sgh30_new(ny,nx) = max(g3) * todouble(lm(ny,nx))
		end if
	end do

	do nx = startnlon + 1,endnlon-1
		gpt_new(ny,nx) = weights_f(gwgt) * gpt(ny,nx)
		sgh_new(ny,nx) = weights_d(gwgt) * sgh(ny,nx)
		sgh30_new(ny,nx) = weights_d(gwgt) * sgh30(ny,nx)
		if (lm(ny,nx) .gt. 0)
			g1 = (/min((/gpt_min,gpt(ny,nx)/)),gpt_new(ny,nx)/)
			gpt_new(ny,nx) = max(g1) * lm(ny,nx)
			g2 = (/min((/sgh_min,sgh(ny,nx)/)),sgh_new(ny,nx)/)
			sgh_new(ny,nx) = max(g2) * todouble(lm(ny,nx))
			g3 = (/min((/sgh30_min,sgh30(ny,nx)/)),sgh30_new(ny,nx)/)
			sgh30_new(ny,nx) = max(g3) * todouble(lm(ny,nx))	
		end if
	end do

	gwgt2 = 0
	do nx = endnlon,endnlon+5
		f2 = (/weights_f(gwgt),weights_f(gwgt2)/)
		gpt_new(ny,nx) = max(f2) * gpt(ny,nx)
                f2_d = (/weights_d(gwgt),weights_d(gwgt2)/)
		sgh_new(ny,nx) = max(f2_d) * sgh(ny,nx)
		sgh30_new(ny,nx) = max(f2_d) * sgh30(ny,nx)

		gwgt2 = gwgt2 + 1
		if (lm(ny,nx) .gt. 0)
			g1 = (/min((/gpt_min,gpt(ny,nx)/)),gpt_new(ny,nx)/)
			gpt_new(ny,nx) = max(g1) * lm(ny,nx)
			g2 = (/min((/sgh_min,sgh(ny,nx)/)),sgh_new(ny,nx)/)
			sgh_new(ny,nx) = max(g2) * todouble(lm(ny,nx))
			g3 = (/min((/sgh30_min,sgh30(ny,nx)/)),sgh30_new(ny,nx)/)
			sgh30_new(ny,nx) = max(g3) * todouble(lm(ny,nx))		
		end if
	end do
	gwgt = gwgt + 1
end do

print(gwgt)
;sponge region western region
gwgt = 5
do nx = startnlon-5,startnlon
	do ny = startnlat + 1,endnlat-1
		gpt_new(ny,nx) = weights_f(gwgt) * gpt(ny,nx)
		sgh_new(ny,nx) = weights_d(gwgt) * sgh(ny,nx)
		sgh30_new(ny,nx) = weights_d(gwgt) * sgh30(ny,nx)
		if (lm(ny,nx) .gt. 0)
			g1 = (/min((/gpt_min,gpt(ny,nx)/)),gpt_new(ny,nx)/)
			gpt_new(ny,nx) = max(g1) * lm(ny,nx)
			g2 = (/min((/sgh_min,sgh(ny,nx)/)),sgh_new(ny,nx)/)
			sgh_new(ny,nx) = max(g2) * todouble(lm(ny,nx))
			g3 = (/min((/sgh30_min,sgh30(ny,nx)/)),sgh30_new(ny,nx)/)
			sgh30_new(ny,nx) = max(g3) * todouble(lm(ny,nx))	
		end if
	end do
	gwgt = gwgt - 1
end do

print(gwgt)

;sponge region eastern region
gwgt = 0
do nx = endnlon,endnlon+5
	do ny = startnlat + 1,endnlat-1
		gpt_new(ny,nx) = weights_f(gwgt) * gpt(ny,nx)
		sgh_new(ny,nx) = weights_d(gwgt) * sgh(ny,nx)
		sgh30_new(ny,nx) = weights_d(gwgt) * sgh30(ny,nx)
		if (lm(ny,nx) .gt. 0)
			g1 = (/min((/gpt_min,gpt(ny,nx)/)),gpt_new(ny,nx)/)
			gpt_new(ny,nx) = max(g1) * lm(ny,nx)
			g2 = (/min((/sgh_min,sgh(ny,nx)/)),sgh_new(ny,nx)/)
			sgh_new(ny,nx) = max(g2) * todouble(lm(ny,nx))
			g3 = (/min((/sgh30_min,sgh30(ny,nx)/)),sgh30_new(ny,nx)/)
			sgh30_new(ny,nx) = max(g3) * todouble(lm(ny,nx))	
		end if
	end do
	gwgt = gwgt + 1
end do

print(gwgt)


do ny = startnlat+1,endnlat-1
	do nx = startnlon + 1,endnlon - 1
		if (lm(ny,nx) .gt. 0)
			gpt_new(ny,nx) = 9.8
			sgh_new(ny,nx) = 9.8
			sgh30_new(ny,nx) = 9.8
		else
			gpt_new(ny,nx) = 0
			sgh_new(ny,nx) = 0
			sgh30_new(ny,nx) = 0
		end if
		if (lm(ny,nx) .gt. 0)
			g1 = (/min((/gpt_min,gpt(ny,nx)/)),gpt_new(ny,nx)/)
			gpt_new(ny,nx) = max(g1) * lm(ny,nx)
			g2 = (/min((/sgh_min,sgh(ny,nx)/)),sgh_new(ny,nx)/)
			sgh_new(ny,nx) = max(g2) * todouble(lm(ny,nx))
			g3 = (/min((/sgh30_min,sgh30(ny,nx)/)),sgh30_new(ny,nx)/)
			sgh30_new(ny,nx) = max(g3) * todouble(lm(ny,nx))	
		end if
	end do
end do


print("reading file in...")
  cdf_out = addfile(fileout1,"w")
print("file read in")

cdf_out ->PHIS(0,:,:)      = (/gpt_new/)

delete(cdf_out)

print("reading file in...")
  cdf_out = addfile(fileout2,"w")
print("file read in")

cdf_out ->PHIS      = (/gpt_new/)
cdf_out ->SGH     = (/sgh_new/)
cdf_out ->SGH30     = (/sgh30_new/)

delete(cdf_out)



end
