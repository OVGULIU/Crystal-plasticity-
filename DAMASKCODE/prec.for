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
!> @author   Franz Roters, Max-Planck-Institut für Eisenforschung GmbH
!> @author   Philip Eisenlohr, Max-Planck-Institut für Eisenforschung GmbH
!> @author   Christoph Kords, Max-Planck-Institut für Eisenforschung GmbH
!> @author   Martin Diehl, Max-Planck-Institut für Eisenforschung GmbH
!> @author   Luv Sharma, Max-Planck-Institut für Eisenforschung GmbH
!> @brief    setting precision for real and int type
!> @details  setting precision for real and int type and for DAMASK_NaN. Definition is made 
!!           depending on makro "INT" defined during compilation
!!           for details on NaN see https://software.intel.com/en-us/forums/topic/294680
!--------------------------------------------------------------------------------------------------
module prec

#if !(defined(__GFORTRAN__) && __GNUC__ < 5)
 use, intrinsic :: &                                                                                ! unfortunately not avialable in gfortran <= 5
  IEEE_arithmetic
#endif

 implicit none
 private 
#if (FLOAT==8)
 integer,     parameter, public :: pReal = 8                                                        !< floating point double precision (was selected_real_kind(15,300), number with 15 significant digits, up to 1e+-300)
#ifdef __INTEL_COMPILER
 real(pReal), parameter, public :: DAMASK_NaN = Z'7FF8000000000000'                                 !< quiet NaN for double precision (from http://www.hpc.unimelb.edu.au/doc/f90lrm/dfum_035.html)
#endif
#ifdef __GFORTRAN__
 real(pReal), parameter, public :: DAMASK_NaN = real(Z'7FF8000000000000',pReal)                     !< quiet NaN for double precision (from http://www.hpc.unimelb.edu.au/doc/f90lrm/dfum_035.html)
#endif
#else
 NO SUITABLE PRECISION FOR REAL SELECTED, STOPPING COMPILATION
#endif

#if (INT==4)
 integer,     parameter, public :: pInt  = 4                                                        !< integer representation 32 bit (was selected_int_kind(9), number with at least up to +- 1e9)
#elif (INT==8)
 integer,     parameter, public :: pInt  = 8                                                        !< integer representation 64 bit (was selected_int_kind(12), number with at least up to +- 1e12)
#else
 NO SUITABLE PRECISION FOR INTEGER SELECTED, STOPPING COMPILATION
#endif

 integer,     parameter, public :: pLongInt  = 8                                                    !< integer representation 64 bit (was selected_int_kind(12), number with at least up to +- 1e12)
 real(pReal), parameter, public :: tol_math_check = 1.0e-8_pReal                                    !< tolerance for internal math self-checks (rotation)

 integer(pInt), allocatable, dimension(:) :: realloc_lhs_test
 
 type, public :: p_vec                                                                              !< variable length datatype used for storage of state
   real(pReal), dimension(:), pointer :: p
 end type p_vec

 type, public :: p_intvec
   integer(pInt), dimension(:), pointer :: p
 end type p_intvec

!http://stackoverflow.com/questions/3948210/can-i-have-a-pointer-to-an-item-in-an-allocatable-array
 type, public :: tState
   integer(pInt) :: &
     sizeState = 0_pInt , &                                                                         !< size of state
     sizeDotState = 0_pInt, &                                                                       !< size of dot state, i.e. parts of the state that are integrated
     sizeDeltaState = 0_pInt, &                                                                     !< size of delta state, i.e. parts of the state that have discontinuous rates
     sizePostResults = 0_pInt                                                                       !< size of output data
   real(pReal), pointer,     dimension(:), contiguous :: &
     atolState
   real(pReal), pointer,     dimension(:,:), contiguous :: &                                        ! a pointer is needed here because we might point to state/doState. However, they will never point to something, but are rather allocated and, hence, contiguous 
     state, &                                                                                       !< state
     dotState, &                                                                                    !< state rate
     state0
   real(pReal), allocatable, dimension(:,:) :: &
     partionedState0, &
     subState0, &
     state_backup, &
     deltaState, &
     previousDotState, &                                                                            !< state rate of previous xxxx
     previousDotState2, &                                                                           !< state rate two xxxx ago
     dotState_backup, &                                                                             !< backup of state rate
     RK4dotState
   real(pReal), allocatable, dimension(:,:,:) :: &
     RKCK45dotState
 end type

 type, extends(tState), public :: tPlasticState
   integer(pInt) :: &
     nSlip = 0_pInt , &
     nTwin = 0_pInt, &
     nTrans = 0_pInt
   logical :: & 
     nonlocal = .false.                                                                             !< absolute tolerance for state integration
   real(pReal), pointer,     dimension(:,:), contiguous :: &
     slipRate, &                                                                                    !< slip rate
     accumulatedSlip                                                                                !< accumulated plastic slip
 end type

 type, public :: tSourceState
   type(tState), dimension(:), allocatable :: p                                                     !< tState for each active source mechanism in a phase
 end type
 
 type, public :: tHomogMapping
   integer(pInt), pointer, dimension(:,:) :: p                                  
 end type 

 type, public :: tPhaseMapping
   integer(pInt), pointer, dimension(:,:,:) :: p
 end type 

#ifdef FEM
 type, public :: tOutputData
   integer(pInt) :: &
     sizeIpCells = 0_pInt , &
     sizeResults = 0_pInt
   real(pReal), allocatable, dimension(:,:) :: &
     output                                                                                         !< output data
 end type 
#endif

 public :: &
   prec_init, &
   prec_isNaN, &
   dEq, &
   dEq0, &
   cEq, &
   dNeq, &
   dNeq0, &
   cNeq
 
contains


!--------------------------------------------------------------------------------------------------
!> @brief reporting precision and checking if DAMASK_NaN is set correctly
!--------------------------------------------------------------------------------------------------
subroutine prec_init
 use, intrinsic :: &
   iso_fortran_env                                                                                  ! to get compiler_version and compiler_options (at least for gfortran 4.6 at the moment)

 implicit none
 external :: &
   quit

 write(6,'(/,a)') ' <<<+-  prec init  -+>>>'
#include "compilation_info.f90"
 write(6,'(a,i3)')    ' Bytes for pReal:    ',pReal
 write(6,'(a,i3)')    ' Bytes for pInt:     ',pInt
 write(6,'(a,i3)')    ' Bytes for pLongInt: ',pLongInt
 write(6,'(a,e10.3)') ' NaN:           ',     DAMASK_NaN
 write(6,'(a,l3)')    ' NaN != NaN:         ',DAMASK_NaN /= DAMASK_NaN
 write(6,'(a,l3,/)')  ' NaN check passed    ',prec_isNAN(DAMASK_NaN)

 if ((.not. prec_isNaN(DAMASK_NaN)) .or. (DAMASK_NaN == DAMASK_NaN)) call quit(9000)
 realloc_lhs_test = [1_pInt,2_pInt]
 if (realloc_lhs_test(2)/=2_pInt) call quit(9000)
 

end subroutine prec_init


!--------------------------------------------------------------------------------------------------
!> @brief figures out if a floating point number is NaN
! basically just a small wrapper, because gfortran < 5.0 does not have the IEEE module
!--------------------------------------------------------------------------------------------------
logical elemental pure function prec_isNaN(a)

 implicit none
 real(pReal), intent(in) :: a

#if (defined(__GFORTRAN__) && __GNUC__ < 5)
 intrinsic :: isNaN
 prec_isNaN = isNaN(a)
#else
 prec_isNaN = IEEE_is_NaN(a)
#endif
end function prec_isNaN


!--------------------------------------------------------------------------------------------------
!> @brief equality comparison for float with double precision
! replaces "==" but for certain (relative) tolerance. Counterpart to dNeq
! http://www.cygnus-software.com/papers/comparingfloats/comparingfloats.htm
!--------------------------------------------------------------------------------------------------
logical elemental pure function dEq(a,b,tol)

 implicit none
 real(pReal), intent(in)           :: a,b
 real(pReal), intent(in), optional :: tol
 real(pReal), parameter            :: eps = 2.220446049250313E-16                                   ! DBL_EPSILON in C

 dEq = merge(.True., .False.,abs(a-b) <= merge(tol,eps,present(tol))*maxval(abs([a,b])))
end function dEq


!--------------------------------------------------------------------------------------------------
!> @brief inequality comparison for float with double precision
! replaces "!=" but for certain (relative) tolerance. Counterpart to dEq
! http://www.cygnus-software.com/papers/comparingfloats/comparingfloats.htm
!--------------------------------------------------------------------------------------------------
logical elemental pure function dNeq(a,b,tol)

 implicit none
 real(pReal), intent(in)           :: a,b
 real(pReal), intent(in), optional :: tol
 real(pReal), parameter            :: eps = 2.220446049250313E-16                                   ! DBL_EPSILON in C

 dNeq = merge(.False., .True.,abs(a-b) <= merge(tol,eps,present(tol))*maxval(abs([a,b])))
end function dNeq


!--------------------------------------------------------------------------------------------------
!> @brief equality to 0comparison for float with double precision
! replaces "==0" but for certain (relative) tolerance. Counterpart to dNeq0
! http://www.cygnus-software.com/papers/comparingfloats/comparingfloats.htm
!--------------------------------------------------------------------------------------------------
logical elemental pure function dEq0(a,tol)

 implicit none
 real(pReal), intent(in)           :: a
 real(pReal), intent(in), optional :: tol
 real(pReal), parameter            :: eps = 2.220446049250313E-16                                   ! DBL_EPSILON in C

 dEq0 = merge(.True., .False.,abs(a) <= merge(tol,eps,present(tol))*abs(a))
end function dEq0


!--------------------------------------------------------------------------------------------------
!> @brief inequality comparison to 0 for float with double precision
! replaces "!=0" but for certain (relative) tolerance. Counterpart to dEq0
! http://www.cygnus-software.com/papers/comparingfloats/comparingfloats.htm
!--------------------------------------------------------------------------------------------------
logical elemental pure function dNeq0(a,tol)

 implicit none
 real(pReal), intent(in)           :: a
 real(pReal), intent(in), optional :: tol
 real(pReal), parameter            :: eps = 2.220446049250313E-16                                   ! DBL_EPSILON in C

 dNeq0 = merge(.False., .True.,abs(a) <= merge(tol,eps,present(tol))*abs(a))
end function dNeq0


!--------------------------------------------------------------------------------------------------
!> @brief equality comparison for complex with double precision
! replaces "==" but for certain (relative) tolerance. Counterpart to cNeq
! http://www.cygnus-software.com/papers/comparingfloats/comparingfloats.htm
! probably a component wise comparison would be more accurate than the comparsion of the absolute
! value
!--------------------------------------------------------------------------------------------------
logical elemental pure function cEq(a,b,tol)

 implicit none
 complex(pReal), intent(in)           :: a,b
 real(pReal),    intent(in), optional :: tol
 real(pReal),    parameter            :: eps = 2.220446049250313E-16                                ! DBL_EPSILON in C

 cEq = merge(.True., .False.,abs(a-b) <= merge(tol,eps,present(tol))*maxval(abs([a,b])))
end function cEq


!--------------------------------------------------------------------------------------------------
!> @brief inequality comparison for complex with double precision
! replaces "!=" but for certain (relative) tolerance. Counterpart to cEq
! http://www.cygnus-software.com/papers/comparingfloats/comparingfloats.htm
! probably a component wise comparison would be more accurate than the comparsion of the absolute
! value
!--------------------------------------------------------------------------------------------------
logical elemental pure function cNeq(a,b,tol)

 implicit none
 complex(pReal), intent(in)           :: a,b
 real(pReal),    intent(in), optional :: tol
 real(pReal),    parameter            :: eps = 2.220446049250313E-16                                ! DBL_EPSILON in C

 cNeq = merge(.False., .True.,abs(a-b) <= merge(tol,eps,present(tol))*maxval(abs([a,b])))
end function cNeq

end module prec
