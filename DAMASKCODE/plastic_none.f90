! Copyright 2011-16 Max-Planck-Institut für Eisenforschung GmbH
! 
! This program is free software: you can redistribute it and/or modify
! it under the terms of the GNU General Public License as published by
! the Free Software Foundation, either version 3 of the License, or
! (at your option) any later version.
! 
! This program is distributed in the hope that it will be useful,
! but WITHOUT ANY WARRANTY; without even the implied warranty of
! MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
! GNU General Public License for more details.
! 
! You should have received a copy of the GNU General Public License
! along with this program. If not, see <http://www.gnu.org/licenses/>.
!--------------------------------------------------------------------------------------------------
!> @author Franz Roters, Max-Planck-Institut für Eisenforschung GmbH
!> @author Philip Eisenlohr, Max-Planck-Institut für Eisenforschung GmbH
!> @brief material subroutine for purely elastic material
!--------------------------------------------------------------------------------------------------
module plastic_none
 use prec, only: &
   pInt

 implicit none
 private
 integer(pInt),                       dimension(:),     allocatable,          public, protected :: &
   plastic_none_sizePostResults

 integer(pInt),                       dimension(:,:),   allocatable, target,  public :: &
   plastic_none_sizePostResult                                                                 !< size of each post result output

 public :: &
   plastic_none_init

contains


!--------------------------------------------------------------------------------------------------
!> @brief module initialization
!> @details reads in material parameters, allocates arrays, and does sanity checks
!--------------------------------------------------------------------------------------------------
subroutine plastic_none_init
 use, intrinsic :: iso_fortran_env                                                                  ! to get compiler_version and compiler_options (at least for gfortran 4.6 at the moment)
 use debug, only: &
   debug_level, &
   debug_constitutive, &
   debug_levelBasic
 use IO, only: &
   IO_timeStamp
 use numerics, only: &
   worldrank, &
   numerics_integrator
 use material, only: &
   phase_plasticity, &
   PLASTICITY_NONE_label, &
   material_phase, &
   plasticState, &
   PLASTICITY_none_ID

 implicit none

 integer(pInt) :: &
   maxNinstance, &
   phase, &
   NofMyPhase, &
   sizeState, &
   sizeDotState, &
   sizeDeltaState
 
 mainProcess: if (worldrank == 0) then 
   write(6,'(/,a)')   ' <<<+-  constitutive_'//PLASTICITY_NONE_label//' init  -+>>>'
   write(6,'(a15,a)') ' Current time: ',IO_timeStamp()
#include "compilation_info.f90"
 endif mainProcess
 
 maxNinstance = int(count(phase_plasticity == PLASTICITY_none_ID),pInt)
 if (maxNinstance == 0_pInt) return

 if (iand(debug_level(debug_constitutive),debug_levelBasic) /= 0_pInt) &
   write(6,'(a16,1x,i5,/)') '# instances:',maxNinstance

 initializeInstances: do phase = 1_pInt, size(phase_plasticity)
   if (phase_plasticity(phase) == PLASTICITY_none_ID) then
   NofMyPhase=count(material_phase==phase)

     sizeState    = 0_pInt
     plasticState(phase)%sizeState = sizeState
     sizeDotState = sizeState
     plasticState(phase)%sizeDotState = sizeDotState
     sizeDeltaState = 0_pInt
     plasticState(phase)%sizeDeltaState = sizeDeltaState
     plasticState(phase)%sizePostResults = 0_pInt
     plasticState(phase)%nSlip  = 0_pInt
     plasticState(phase)%nTwin  = 0_pInt
     plasticState(phase)%nTrans = 0_pInt
     allocate(plasticState(phase)%aTolState          (sizeState))
     allocate(plasticState(phase)%state0             (sizeState,NofMyPhase))
     allocate(plasticState(phase)%partionedState0    (sizeState,NofMyPhase))
     allocate(plasticState(phase)%subState0          (sizeState,NofMyPhase))
     allocate(plasticState(phase)%state              (sizeState,NofMyPhase))
     allocate(plasticState(phase)%state_backup       (sizeState,NofMyPhase))

     allocate(plasticState(phase)%dotState           (sizeDotState,NofMyPhase))
     allocate(plasticState(phase)%deltaState        (sizeDeltaState,NofMyPhase))
     allocate(plasticState(phase)%dotState_backup    (sizeDotState,NofMyPhase))
     if (any(numerics_integrator == 1_pInt)) then
       allocate(plasticState(phase)%previousDotState (sizeDotState,NofMyPhase))
       allocate(plasticState(phase)%previousDotState2(sizeDotState,NofMyPhase))
     endif
     if (any(numerics_integrator == 4_pInt)) &
       allocate(plasticState(phase)%RK4dotState      (sizeDotState,NofMyPhase))
     if (any(numerics_integrator == 5_pInt)) &
       allocate(plasticState(phase)%RKCK45dotState (6,sizeDotState,NofMyPhase))
   endif
 enddo initializeInstances

 allocate(plastic_none_sizePostResults(maxNinstance), source=0_pInt)

end subroutine plastic_none_init

end module plastic_none
