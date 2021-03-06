!
! PIERNIK Code Copyright (C) 2006 Michal Hanasz
!
!    This file is part of PIERNIK code.
!
!    PIERNIK is free software: you can redistribute it and/or modify
!    it under the terms of the GNU General Public License as published by
!    the Free Software Foundation, either version 3 of the License, or
!    (at your option) any later version.
!
!    PIERNIK is distributed in the hope that it will be useful,
!    but WITHOUT ANY WARRANTY; without even the implied warranty of
!    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
!    GNU General Public License for more details.
!
!    You should have received a copy of the GNU General Public License
!    along with PIERNIK.  If not, see <http://www.gnu.org/licenses/>.
!
!    Initial implementation of PIERNIK code was based on TVD split MHD code by
!    Ue-Li Pen
!        see: Pen, Arras & Wong (2003) for algorithm and
!             http://www.cita.utoronto.ca/~pen/MHD
!             for original source code "mhd.f90"
!
!    For full list of developers see $PIERNIK_HOME/license/pdt.txt
!
#include "piernik.h"

module initproblem

! Initial condition for blob test
! Blob test by Agertz et al., 2007, MNRAS, 380, 963.
! ToDo: write support for original, SPH-noisy, initial conditions

   implicit none

   private
   public :: read_problem_par, problem_initial_conditions, problem_pointers

   real   :: chi, rblob, blobxc, blobyc, blobzc, Mext, denv, tkh, vgal

   namelist /PROBLEM_CONTROL/  chi, rblob, blobxc, blobyc, blobzc, Mext, denv, tkh, vgal

contains

!-----------------------------------------------------------------------------

   subroutine problem_pointers

      implicit none

   end subroutine problem_pointers

!-----------------------------------------------------------------------------

   subroutine read_problem_par

      use dataio_pub, only: nh   ! QA_WARN required for diff_nml
      use mpisetup,   only: rbuff, master, slave, piernik_MPI_Bcast

      implicit none

      chi     = 10.0
      rblob   =  1.0
      blobxc  =  5.0
      blobyc  =  5.0
      blobzc  =  5.0
      Mext    =  2.7
      denv    =  1.0
      tkh     =  1.7
      vgal    =  0.0

      if (master) then

         if (.not.nh%initialized) call nh%init()
         open(newunit=nh%lun, file=nh%tmp1, status="unknown")
         write(nh%lun,nml=PROBLEM_CONTROL)
         close(nh%lun)
         open(newunit=nh%lun, file=nh%par_file)
         nh%errstr=""
         read(unit=nh%lun, nml=PROBLEM_CONTROL, iostat=nh%ierrh, iomsg=nh%errstr)
         close(nh%lun)
         call nh%namelist_errh(nh%ierrh, "PROBLEM_CONTROL")
         read(nh%cmdl_nml,nml=PROBLEM_CONTROL, iostat=nh%ierrh)
         call nh%namelist_errh(nh%ierrh, "PROBLEM_CONTROL", .true.)
         open(newunit=nh%lun, file=nh%tmp2, status="unknown")
         write(nh%lun,nml=PROBLEM_CONTROL)
         close(nh%lun)
         call nh%compare_namelist()

         rbuff(1) = chi
         rbuff(2) = rblob
         rbuff(3) = blobxc
         rbuff(4) = blobyc
         rbuff(5) = blobzc
         rbuff(6) = Mext
         rbuff(7) = denv
         rbuff(8) = tkh
         rbuff(9) = vgal

      endif

      call piernik_MPI_Bcast(rbuff)

      if (slave) then

         chi      = rbuff(1)
         rblob    = rbuff(2)
         blobxc   = rbuff(3)
         blobyc   = rbuff(4)
         blobzc   = rbuff(5)
         Mext     = rbuff(6)
         denv     = rbuff(7)
         tkh      = rbuff(8)
         vgal     = rbuff(9)

      endif

   end subroutine read_problem_par

!-----------------------------------------------------------------------------

   subroutine problem_initial_conditions

      use cg_leaves,  only: leaves
      use cg_list,    only: cg_list_element
      use constants,  only: xdim, ydim, zdim, LO, HI
      use domain,     only: dom
      use fluidindex, only: flind
      use fluidtypes, only: component_fluid
      use grid_cont,  only: grid_container

      implicit none

      class(component_fluid), pointer :: fl
      real                            :: penv, rcx, rcy, rrel
      integer                         :: i, j, k
      type(cg_list_element),  pointer :: cgl
      type(grid_container),   pointer :: cg

      fl => flind%neu

      penv = 3.2*rblob*sqrt(chi)/tkh/(Mext*fl%gam/denv)

      cgl => leaves%first
      do while (associated(cgl))
         cg => cgl%cg

         cg%u(fl%imz, :, :, :) = 0.0
         cg%u(fl%ien, :, :, :) = penv/fl%gam_1

         do i = cg%lhn(xdim,LO), cg%lhn(xdim,HI)
            rcx = (cg%x(i)-blobxc)**2
            do j = cg%lhn(ydim,LO), cg%lhn(ydim,HI)
               rcy = (cg%y(j)-blobyc)**2
               do k = cg%lhn(zdim,LO), cg%lhn(zdim,HI)
                  if (dom%has_dir(zdim)) then
                     rrel = sqrt(rcx + rcy + (cg%z(k)-blobzc)**2)
                  else
                     rrel = sqrt(rcx + rcy)
                  endif

                  if (rblob >= rrel) then
                     cg%u(fl%idn,i,j,k) = chi*denv
                     cg%u(fl%imx,i,j,k) = chi*denv*vgal
                     cg%u(fl%imy,i,j,k) = 0.0
                  else
                     cg%u(fl%idn,i,j,k) = denv
                     cg%u(fl%imx,i,j,k) = denv*vgal
                     cg%u(fl%imy,i,j,k) = Mext*fl%gam*penv
                  endif
               enddo
            enddo
         enddo

         cgl => cgl%nxt
      enddo

   end subroutine problem_initial_conditions

!------------------------------------------------------------------------------------------

end module initproblem
