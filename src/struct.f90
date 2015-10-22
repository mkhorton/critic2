! Copyright (c) 2015 Alberto Otero de la Roza
! <alberto@fluor.quimica.uniovi.es>,
! Ángel Martín Pendás <angel@fluor.quimica.uniovi.es> and Víctor Luaña
! <victor@fluor.quimica.uniovi.es>.
!
! critic2 is free software: you can redistribute it and/or modify
! it under the terms of the GNU General Public License as published by
! the Free Software Foundation, either version 3 of the License, or
! (at
! your option) any later version.
!
! critic2 is distributed in the hope that it will be useful,
! but WITHOUT ANY WARRANTY; without even the implied warranty of
! MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
! GNU General Public License for more details.
!
! You should have received a copy of the GNU General Public License
! along with this program.  If not, see
! <http://www.gnu.org/licenses/>.

! Geometry of the crystal: variables and tools.
module struct
  use types
  implicit none

  private
  public :: struct_crystal_input
  public :: struct_clearsym
  public :: struct_charges
  public :: struct_write
  public :: struct_powder
  public :: struct_compare
  public :: struct_environ
  public :: struct_packing
  public :: struct_newcell
  public :: struct_molcell

contains

  !xx! top-level routines
  !> Parse the input of the crystal keyword
  subroutine struct_crystal_input(c,line,mol,allownofile,verbose) 
    use struct_readers
    use struct_basic
    use global
    use tools_io
    use param

    character*(*), intent(in) :: line
    logical, intent(in) :: mol
    type(crystal), intent(inout) :: c
    logical, intent(in) :: allownofile
    logical, intent(in) :: verbose

    integer :: lp, lp2
    character(len=:), allocatable :: word, word2, wext1, wext2, subline, aux
    integer :: ntyp, nn
    character*5 :: ztyp(100)
    real*8 :: x0(3), rborder, raux
    real*8, parameter :: rborder_def = 3d0
    logical :: docube

    ! Initialize the structure
    call c%end()
    call c%init()

    ! save whether this is a crystal or a molecule
    c%ismolecule = mol
    c%molx0 = 0d0

    ! enforce MOLECULE keyword particular settings
    if (c%ismolecule) then
       ! deactivate symmetry
       doguess = .false.
    end if

    ! read and parse
    lp=1
    word = getword(line,lp)
    aux = word(index(word,dirsep,.true.)+1:)
    wext1 = aux(index(aux,'.',.true.)+1:)
    aux = word(index(word,dirsep,.true.)+1:)
    wext2 = aux(index(aux,'_',.true.)+1:)
    c%file = ""

    if (equal(wext1,'cif')) then
       aux = getword(line,lp)
       if (equal(aux,"")) then
          aux = " "
       end if
       call struct_read_cif(c,word,aux,.false.)
       call c%set_cryscar()
       c%file = word

    else if (equal(wext1,'cube')) then
       call struct_read_cube(c,word,.false.)
       call c%guessspg(.false.)
       aux = getword(line,lp)
       if (len_trim(aux) > 0) call ferror('struct_crystal_input','Unknown extra keyword in CRYSTAL',faterr,line)
       c%file = word

    else if (equal(wext1,'struct')) then
       call struct_read_wien(c,word,.false.)
       call c%set_cryscar()
       if (c%neqv == 0) then ! some structs may come without symmetry
          call struct_read_wien(cr,word,.true.)
          call c%set_cryscar()
          call c%guessspg(.false.)
       endif
       aux = getword(line,lp)
       if (len_trim(aux) > 0) call ferror('struct_crystal_input','Unknown extra keyword in CRYSTAL',faterr,line)
       c%file = word

    else if (equal(wext1,'POSCAR') .or. equal(wext1,'CONTCAR') .or.&
       & equal(wext1,'CHGCAR') .or. equal(wext1,'CHG') .or.&
       & equal(wext1,'ELFCAR')) then
       wext1 = getword(line,lp)
       wext2 = wext1(index(wext1,dirsep,.true.)+1:)
       wext2 = wext2(index(wext2,'.',.true.)+1:)
       if (equal(wext2,'POTCAR')) then
          call struct_read_potcar(wext1,ntyp,ztyp)
          aux = getword(line,lp)
          if (len_trim(aux) > 0) call ferror('struct_crystal_input','Unknown extra keyword in CRYSTAL',faterr,line)
       else
          ntyp = 0
          ztyp = ""
          do while(.true.)
             nn = zatguess(wext1)
             if (nn >= 0) then
                ntyp = ntyp + 1
                ztyp(ntyp) = string(wext1)
             else
                if (len_trim(wext1) > 0) call ferror('struct_crystal_input','Unknown atom type in CRYSTAL',faterr,line)
                exit
             end if
             wext1 = getword(line,lp)
          end do
       end if
       call struct_read_vasp(c,word,ntyp,ztyp)
       call c%guessspg(.false.)
       c%file = word

    else if (equal(wext1,'DEN') .or. equal(wext2,'DEN')) then
       call struct_read_abinit(c,word)
       aux = getword(line,lp)
       if (len_trim(aux) > 0) call ferror('struct_crystal_input','Unknown extra keyword in CRYSTAL',faterr,line)
       c%file = word

    else if (equal(wext1,'OUT')) then
       call struct_read_elk(c,word)
       call c%guessspg(.false.)
       aux = getword(line,lp)
       if (len_trim(aux) > 0) call ferror('struct_crystal_input','Unknown extra keyword in CRYSTAL',faterr,line)
       c%file = word

    else if (equal(wext1,'out')) then
       call struct_read_qeout(c,word)
       call c%guessspg(.false.)
       aux = getword(line,lp)
       if (len_trim(aux) > 0) call ferror('struct_crystal_input','Unknown extra keyword in CRYSTAL',faterr,line)
       c%file = word

    else if (equal(wext1,'in')) then
       call struct_read_qein(c,word)
       call c%guessspg(.false.)
       aux = getword(line,lp)
       if (len_trim(aux) > 0) call ferror('struct_crystal_input','Unknown extra keyword in CRYSTAL',faterr,line)
       c%file = word

    else if (equal(word,'library')) then
       subline = line(lp:)
       call struct_read_library(c,subline,x0)
       c%file = "library (" // trim(line(lp:)) // ")"

    else if (equal(wext1,'xyz').or.equal(wext1,'wfn').or.equal(wext1,'wfx')) then
       docube = .false.
       rborder = rborder_def
       do while(.true.)
          lp2 = 1
          word2 = lgetword(line,lp)
          if (equal(word2,'cubic').or.equal(word2,'cube')) then
             docube = .true.
          elseif (eval_next(raux,word2,lp2)) then
             rborder = raux
          elseif (len_trim(word2) > 1) then
             call ferror('struct_write','Unknown extra keyword',faterr,line)
          else
             exit
          end if
       end do
       call struct_read_mol(c,word,wext1,rborder,docube)
       call c%set_cryscar()
       call c%guessspg(.false.)
       aux = getword(line,lp)
       if (len_trim(aux) > 0) call ferror('struct_crystal_input','Unknown extra keyword in CRYSTAL',faterr,line)
       c%file = word

    else if (equal(wext1,'STRUCT_OUT') .or. equal(wext1,'STRUCT_IN'))&
       & then
       call struct_read_siesta(c,word)
       call c%guessspg(.false.)
       aux = getword(line,lp)
       if (len_trim(aux) > 0) call ferror('struct_crystal_input','Unknown extra keyword in CRYSTAL',faterr,line)
       c%file = word

    else if (len_trim(word) < 1) then
       if (.not.allownofile) call ferror('struct_crystal_input','Attempted to parse CRYSTAL environment but allownofile=.true.',faterr)
       call parse_crystal_env(c,uin,x0)
       c%file = "<input>"

    else
       call ferror('struct_crystal_input','unrecognized file format'&
          &,faterr,line)
    end if

    call c%struct_fill(verbose)

  end subroutine struct_crystal_input

  ! use the P1 space group
  subroutine struct_clearsym()
    use struct_basic
    use types
    use tools_io
    use param

    type(atom) :: aux(cr%nneq)
    integer :: i

    ! nullify the space group
    cr%neqv = 1
    cr%rotm(:,:,1) = eyet
    cr%ncv = 1
    if (allocated(cr%cen)) deallocate(cr%cen)
    allocate(cr%cen(3,4))
    cr%cen = 0d0
    cr%lcent = 1

    ! convert ncel to nneq
    aux = cr%at(1:cr%nneq)
    cr%nneq = cr%ncel
    call realloc(cr%at,cr%ncel)
    do i = 1, cr%ncel
       cr%at(i) = aux(cr%atcel(i)%idx)
       cr%at(i)%x = cr%atcel(i)%x
    end do

    write (uout,'("* CLEARSYM: clear all symmetry operations and rebuild the atom list.")')
    write (uout,'("            The new crystal description follows"/)')
    call cr%struct_fill(.true.)

  end subroutine struct_clearsym

  subroutine struct_charges(line)
    use struct_basic
    use global
    use tools_io

    character*(*), intent(in) :: line

    character(len=:), allocatable :: word
    integer :: lp, lp2, nn, i, xx
    logical :: ok, do1

    lp = 1
    word = lgetword(line,lp)
    if (equal(word,'q') .or. equal(word,'zpsp') .or. equal(word,'qat')) then
       do1 = equal(word,'zpsp')
       do while (.true.)
          lp2 = lp
          ok = eval_next(nn,line,lp)
          if (ok) then
             ok = eval_next(xx,line,lp)
             if (.not.ok) &
                call ferror('struct_charges','Incorrect Q/QAT/ZPSP syntax',faterr,line)
             if (do1) then
                cr%at(nn)%zpsp = xx
             else
                cr%at(nn)%qat = xx
             end if
          else 
             lp = lp2
             word = getword(line,lp)
             if (len_trim(word) < 1) exit
             nn = zatguess(word)
             if (nn == -1) &
                call ferror('struct_charges','Unknown atomic symbol in Q/QAT/ZPSP',faterr,line)
             ok = eval_next(xx,line,lp)
             if (.not.ok) &
                call ferror('struct_charges','Incorrect Q/QAT/ZPSP syntax',faterr,line)
             do i = 1, cr%nneq
                if (cr%at(i)%z == nn) then
                   if (do1) then
                      cr%at(i)%zpsp = xx
                   else
                      cr%at(i)%qat = xx
                   end if
                endif
             end do
          endif
       end do
    elseif (equal(word,'nocore')) then
       cr%at(1:cr%nneq)%zpsp = -1
       word = getword(line,lp)
       if (len_trim(word) > 0) &
          call ferror('critic','Unknown extra keyword',faterr,line)
    endif

  end subroutine struct_charges

  ! Write the crystal structure to a file
  subroutine struct_write(line)
    use struct_writers
    use struct_basic
    use global
    use tools_io
    use param

    character*(*), intent(in) :: line

    character(len=:), allocatable :: word, wext, file, wroot
    integer :: lp, ix(3), lp2, iaux
    logical :: doborder, molmotif, doprim, dodreiding, docell, domolcell, ok
    logical :: doburst
    real*8 :: rsph, xsph(3), rcub, xcub(3)

    lp = 1
    file = getword(line,lp)
    wext = lower(file(index(file,'.',.true.)+1:))
    wroot = file(:index(file,'.',.true.)-1)

    ! scan for keywords common to many formats
    doprim = .false.
    lp2 = lp
    do while(.true.)
       word = lgetword(line,lp2)
       if (equal(word,'primitive')) then
          doprim = .true.
       else
          exit
       endif
    end do

    if (equal(wext,'xyz').or.equal(wext,'gjf').or.equal(wext,'obj').or.&
        equal(wext,'ply').or.equal(wext,'off')) then
       ! xyz, gjf, obj, ply, off
       doborder = .false.
       molmotif = .false.
       docell = .false.
       domolcell = .false.
       doburst = .false.
       ix = 1
       rsph = -1d0
       xsph = 0d0
       rcub = -1d0
       xcub = 0d0
       do while(.true.)
          word = lgetword(line,lp)
          lp2 = 1
          if (equal(word,'border')) then
             doborder = .true.
          elseif (equal(word,'molmotif')) then
             molmotif = .true.
          elseif (equal(word,'burst')) then
             doburst = .true.
          elseif (equal(word,'cell')) then
             docell = .true.
          elseif (equal(word,'molcell')) then
             domolcell = .true.
          elseif (equal(word,'sphere')) then
             ok = eval_next(rsph,line,lp)
             ok = ok .and. eval_next(xsph(1),line,lp)
             if (ok) then
                ok = ok .and. eval_next(xsph(2),line,lp)
                ok = ok .and. eval_next(xsph(3),line,lp)
                if (.not.ok) call ferror('struct_write','incorrect&
                   & WRITE SPHERE syntax',faterr,line)
             else
                xsph = 0d0
             end if
          elseif (equal(word,'cube')) then
             ok = eval_next(rcub,line,lp)
             ok = ok .and. eval_next(xcub(1),line,lp)
             if (ok) then
                ok = ok .and. eval_next(xcub(2),line,lp)
                ok = ok .and. eval_next(xcub(3),line,lp)
                if (.not.ok) call ferror('struct_write','incorrect&
                   & WRITE CUBE syntax',faterr,line)
             else
                xcub = 0d0
             end if
          elseif (eval_next(iaux,word,lp2)) then
             ix(1) = iaux
             ok = eval_next(ix(2),line,lp)
             ok = ok .and. eval_next(ix(3),line,lp)
             if (.not.ok) call ferror('struct_write','incorrect WRITE&
                & syntax',faterr,line)
          elseif (len_trim(word) > 1) then
             call ferror('struct_write','Unknown extra keyword',faterr,line)
          else
             exit
          end if
       end do

       if (.not.doburst) then
          write (uout,'("* WRITE ",A," file: ",A)') trim(wext), string(file)
       else
          write (uout,'("* WRITE ",A," files: ",A,"_*.",A)') trim(wext), &
             string(wroot), trim(wext)
       end if

       if (equal(wext,'xyz').or.equal(wext,'gjf')) then
          call struct_write_mol(cr,file,wext,ix,doborder,molmotif,doburst,&
             rsph,xsph,rcub,xcub)
       else
          call struct_write_3dmodel(cr,file,wext,ix,doborder,molmotif,doburst,&
             docell,domolcell,rsph,xsph,rcub,xcub)
       end if
    elseif (equal(wext,'in')) then
       ! espresso
       write (uout,'("* WRITE espresso file: ",A)') string(file)
       call struct_write_espresso(file,cr,doprim)
       call check_no_extra_word()
    elseif (equal(wext,'poscar') .or. equal(wext,'contcar')) then
       ! vasp
       write (uout,'("* WRITE VASP file: ",A)') string(file)
       call struct_write_vasp(file,cr,doprim,.true.)
       call check_no_extra_word()
    elseif (equal(wext,'abin')) then
       ! abinit
       write (uout,'("* WRITE abinit file: ",A)') string(file)
       call struct_write_abinit(file,cr,doprim)
       call check_no_extra_word()
    elseif (equal(wext,'elk')) then
       ! elk
       write (uout,'("* WRITE elk file: ",A)') string(file)
       call struct_write_elk(file,cr,doprim)
       call check_no_extra_word()
    elseif (equal(wext,'tess')) then
       ! tessel
       write (uout,'("* WRITE tess file: ",A)') string(file)
       call struct_write_tessel(file,cr)
       call check_no_extra_word()
    elseif (equal(wext,'incritic').or.equal(wext,'cri')) then
       ! critic2
       write (uout,'("* WRITE critic2 input file: ",A)') string(file)
       call struct_write_critic(file,cr)
       call check_no_extra_word()
    elseif (equal(wext,'cif')) then
       ! cif
       write (uout,'("* WRITE cif file: ",A)') string(file)
       call struct_write_cif(file,cr)
       call check_no_extra_word()
    elseif (equal(wext,'m')) then
       ! escher
       write (uout,'("* WRITE escher file: ",A)') string(file)
       call struct_write_escher(file,cr)
       call check_no_extra_word()
    elseif (equal(wext,'gin')) then
       ! gulp
       dodreiding = .false.
       do while(.true.)
          word = lgetword(line,lp)
          if (equal(word,'dreiding')) then
             dodreiding = .true.
          elseif (len_trim(word) > 1) then
             call ferror('struct_write','Unknown extra keyword',faterr,line)
          else
             exit
          end if
       end do
       write (uout,'("* WRITE gulp file: ",A)') string(file)
       call struct_write_gulp(file,cr,dodreiding)
    elseif (equal(wext,'lammps')) then
       write (uout,'("* WRITE lammps file: ",A)') string(file)
       call struct_write_lammps(file,cr)
       call check_no_extra_word()
    elseif (equal(wext,'fdf')) then
       write (uout,'("* WRITE fdf file: ",A)') string(file)
       call struct_write_siesta_fdf(file,cr)
       call check_no_extra_word()
    elseif (equal(wext,'struct_in')) then
       write (uout,'("* WRITE STRUCT_IN file: ",A)') string(file)
       call struct_write_siesta_in(file,cr)
       call check_no_extra_word()
    else
       call ferror('struct_write','unrecognized file format',faterr,line)
    end if
    write (uout,*)

  contains
    subroutine check_no_extra_word()
      character(len=:), allocatable :: aux2

      do while (.true.)
         aux2 = getword(line,lp)
         if (equal(aux2,'primitive')) cycle
         if (len_trim(aux2) > 0) &
            call ferror('struct_write','Unknown extra keyword',faterr,line)
         exit
      end do

    end subroutine check_no_extra_word
  end subroutine struct_write

  !> Calculate the powder diffraction pattern for the current
  !structure.
  subroutine struct_powder(line,c)
    use struct_basic
    use global
    use tools_io
    use tools
    use param
    character*(*), intent(in) :: line
    type(crystal), intent(in) :: c

    integer :: i, lp, lu, np, npts
    real*8 :: th2ini, th2end, lambda, fpol, sigma
    real*8, allocatable :: t(:), ih(:), th2p(:), ip(:)
    integer, allocatable :: hvecp(:,:)
    character(len=:), allocatable :: root, word
    logical :: ok

    ! default values
    th2ini = 5d0 
    th2end = 90d0 
    lambda = 1.5406d0
    fpol = 0d0 ! polarization, fpol = 0.95 for synchrotron
    npts = 10001
    sigma = 0.05d0
    root = trim(fileroot) // "_xrd"

    ! header
    write (uout,'("* POWDER: powder diffraction pattern")')
    write (uout,*)

    ! parse input
    lp = 1
    do while (.true.)
       word = lgetword(line,lp)
       if (equal(word,"th2ini")) then
          ok = eval_next(th2ini,line,lp)
          if (.not.ok) call ferror('struct_powder','Incorrect TH2INI',faterr,line)
       elseif (equal(word,"th2end")) then
          ok = eval_next(th2end,line,lp)
          if (.not.ok) call ferror('struct_powder','Incorrect TH2END',faterr,line)
       elseif (equal(word,"l").or.equal(word,"lambda")) then
          ok = eval_next(lambda,line,lp)
          if (.not.ok) call ferror('struct_powder','Incorrect LAMBDA',faterr,line)
       elseif (equal(word,"fpol")) then
          ok = eval_next(fpol,line,lp)
          if (.not.ok) call ferror('struct_powder','Incorrect FPOL',faterr,line)
       elseif (equal(word,"npts")) then
          ok = eval_next(npts,line,lp)
          if (.not.ok) call ferror('struct_powder','Incorrect NPTS',faterr,line)
       elseif (equal(word,"sigma")) then
          ok = eval_next(sigma,line,lp)
          if (.not.ok) call ferror('struct_powder','Incorrect SIGMA',faterr,line)
       elseif (equal(word,"root")) then
          root = getword(line,lp)
       elseif (len_trim(word) > 0) then
          call ferror('struct_powder','Unknown extra keyword',faterr,line)
       else
          exit
       end if
    end do

    call c%powder(th2ini,th2end,npts,lambda,fpol,sigma,t,ih,th2p,ip,hvecp)
    np = size(th2p)

    ! write the data file 
    lu = fopen_write(trim(root) // ".dat")
    write (lu,'("# ",A,A)') string("2*theta",13,ioj_center), string("Intensity",13,ioj_center)
    do i = 1, npts
       write (lu,'(A,X,A)') string(t(i),"f",15,7,ioj_center), &
          string(ih(i),"f",15,7,ioj_center)
    end do
    call fclose(lu)
    deallocate(t,ih)

    ! write the gnuplot input file
    lu = fopen_write(trim(root) // ".gnu")
    write (lu,'("set terminal postscript eps color enhanced ""Helvetica"" 25")')
    write (lu,'("set output """,A,".eps""")') trim(root)
    write (lu,*)
    do i = 1, np
       write (lu,'("set label ",A," """,A,A,A,""" at ",A,",",A," center rotate by 90 font ""Helvetica,12""")') &
          string(i), string(hvecp(1,i)), string(hvecp(2,i)), string(hvecp(3,i)), &
          string(th2p(i)*180/pi,"f"), string(min(ip(i)+4,102d0),"f")
    end do
    write (lu,*)
    write (lu,'("set xlabel ""2{/Symbol Q} (degrees)""")')
    write (lu,'("set ylabel ""Intensity (arb. units)""")')
    write (lu,'("set xrange [",A,":",A,"]")') string(th2ini,"f"), string(th2end,"f")
    write (lu,'("set style data lines")')
    write (lu,'("set grid")')
    write (lu,'("unset key")')
    write (lu,'("plot """,A,".dat"" w lines")') string(root)
    write (lu,*)
    call fclose(lu)

    ! list of peaks and intensity in output
    write(uout,'("#i  h  k  l       2*theta        Intensity ")')
    do i = 1, np
       write (uout,'(99(A,X))') string(i,3), string(hvecp(1,i),2), string(hvecp(2,i),2),&
          string(hvecp(3,i),2), string(th2p(i)*180/pi,"f",15,7,7), string(ip(i),"f",15,7,7)
    end do
    write (uout,*)

    if (allocated(t)) deallocate(t)
    if (allocated(ih)) deallocate(ih)
    if (allocated(th2p)) deallocate(th2p)
    if (allocated(ip)) deallocate(ip)
    if (allocated(hvecp)) deallocate(hvecp)
    
  end subroutine struct_powder

  !> Compare two crystal structures using the powder diffraction patterns.
  subroutine struct_compare(line)
    use global
    use tools_io
    use struct_basic
    character*(*), intent(in) :: line

    character(len=:), allocatable :: word
    logical :: doguess0
    integer :: lp, i, j
    integer :: ns
    type(crystal), allocatable :: c(:), caux(:)
    real*8 :: tini, tend, nor
    real*8, allocatable :: t(:), ih(:), th2p(:), ip(:), iha(:,:)
    integer, allocatable :: hvecp(:,:)
    real*8, allocatable :: powdiff(:,:)

    real*8, parameter :: sigma0 = 0.2d0
    real*8, parameter :: lambda0 = 1.5406d0
    real*8, parameter :: fpol0 = 0d0
    integer, parameter :: npts = 10001
    real*8, parameter :: th2ini = 5d0
    real*8, parameter :: th2end = 90d0

    ! initialized
    doguess0 = doguess
    lp = 1
    ns = 0
    allocate(c(2))

    write (uout,'("* COMPARE: compare crystal structures")')

    ! load all the crystal structures
    doguess = .false.
    do while(.true.)
       word = getword(line,lp)
       if (len_trim(word) > 0) then
          ns = ns + 1
          if (ns > size(c)) then
             allocate(caux(2*size(c)))
             caux(1:size(c)) = c
             call move_alloc(caux,c)
          endif
          if (equal(word,".")) then
             if (.not.cr%isinit) &
                call ferror('struct_compare','Current structure is not initialized. Use CRYSTAL before COMPARE.',faterr)
             write (uout,'("  Crystal ",A,": <current>")') string(ns,2)
             c(ns) = cr
          else
             write (uout,'("  Crystal ",A,": ",A)') string(ns,2), string(word) 
             call struct_crystal_input(c(ns),word,.false.,.false.,.false.)
          end if
       else
          exit
       end if
    end do
    write (uout,*)

    if (ns < 2) &
       call ferror('struct_compare','At least 2 structures are needed for the comparison',faterr)

    allocate(iha(10001,ns))
    do i = 1, ns
       ! calculate the powder diffraction pattern
       call c(i)%powder(th2ini,th2end,npts,lambda0,fpol0,sigma0,t,ih,th2p,ip,hvecp)

       ! normalize the integral of abs(ih)
       tini = abs(ih(1))
       tend = abs(ih(npts))
       nor = (2d0 * sum(abs(ih(2:npts-1))) + tini + tend) * (th2end - th2ini) / 2d0 / real(npts-1,8)
       iha(:,i) = ih / nor
    end do
    if (allocated(t)) deallocate(t)
    if (allocated(ih)) deallocate(ih)
    if (allocated(th2p)) deallocate(th2p)
    if (allocated(ip)) deallocate(ip)
    if (allocated(hvecp)) deallocate(hvecp)

    ! calculate the overlap between diffraction patterns
    allocate(powdiff(ns,ns))
    powdiff = 0d0
    do i = 1, ns
       do j = i, ns
          tini = abs(iha(1,i)-iha(1,j))
          tend = abs(iha(npts,i)-iha(npts,j))
          powdiff(i,j) = (2d0 * sum(abs(iha(2:npts-1,i) - iha(2:npts-1,j))) + tini + tend) &
             * (th2end - th2ini) / 2d0 / real(npts-1,8)
          powdiff(j,i) = powdiff(i,j)
       end do
    end do
    
    ! write output 
    if (ns == 2) then
       write (uout,'("+ POWDIFF = ",A)') string(powdiff(1,2),'e',12,6)
    else
       do i = 1, ns
          do j = i+1, ns
             write (uout,'("+ POWDIFF(",A,",",A,") = ",A)') string(i), string(j), &
                string(powdiff(i,j),'e',12,6)
          end do
       end do
    endif
    write (uout,*)

    ! clean up
    deallocate(powdiff)
    doguess = doguess0

  end subroutine struct_compare

  !> Calculate the atomic environment of a point or all the 
  !> non-equivalent atoms in the unit cell.
  subroutine struct_environ(line)
    use struct_basic
    use global
    use tools_io
    use tools
    use param
    character*(*), intent(in) :: line

    integer :: lp
    integer :: nn, i, j, k, l
    real*8 :: x0(3)
    logical :: doatoms, ok
    character(len=:), allocatable :: word
    integer, allocatable :: nneig(:), wat(:)
    real*8, allocatable :: dist(:), xenv(:,:,:)

    nn = 10
    x0 = 0d0
    doatoms = .true.

    ! parse input
    lp = 1
    do while (.true.)
       word = lgetword(line,lp)
       if (equal(word,"shells")) then
          ok = eval_next(nn,line,lp)
          if (.not.ok) call ferror('struct_environ','Wrong SHELLS syntax',faterr,line)
       elseif (equal(word,"point")) then
          ok = eval_next(x0(1),line,lp)
          ok = ok .and. eval_next(x0(2),line,lp)
          ok = ok .and. eval_next(x0(3),line,lp)
          if (.not.ok) call ferror('struct_environ','Wrong POINT syntax',faterr,line)
          doatoms = .false.
       elseif (len_trim(word) > 0) then
          call ferror('struct_environ','Unknown extra keyword',faterr,line)
       else
          exit
       end if
    end do

    write (uout,'("* ENVIRON")')
    allocate(nneig(nn),wat(nn),dist(nn))
    if (doatoms) then
       write (uout,'("+ Atomic environments")')
       write (uout,'("     Atom     neig       d (a.u.)    nneq  type        position (cryst. coords)")')
       do i = 1, cr%nneq
          call cr%pointshell(cr%at(i)%x,nn,nneig,wat,dist,xenv)
          do j = 1, nn
             if (j == 1) then
                write (uout,'(I3,1X,"(",A4,")",4X,I4,3X,F12.7,3X,I4,3X,A4,3A)') &
                   i, cr%at(i)%name, nneig(j), dist(j), wat(j), &
                   cr%at(wat(j))%name, (string(xenv(k,1,j),'f',12,7,ioj_right),k=1,3)
             else
                if (wat(j) /= 0) then
                   write (uout,'(5X,"...",6X,I4,3X,F12.7,3X,I4,3X,A4,3A)') &
                      nneig(j), dist(j), wat(j), cr%at(wat(j))%name,&
                      (string(xenv(k,1,j),'f',12,7,ioj_right),k=1,3)
                end if
             end if
          end do
       end do
       write (uout,*)
    else
       call cr%pointshell(x0,nn,nneig,wat,dist,xenv)
       ! List of atomic environments
       write (uout,'("+ Atomic environments of (",A,",",A,",",A,")")') &
          string(x0(1),'f'), string(x0(2),'f'), string(x0(3),'f')
       write (uout,'("     Atom     neig       d (a.u.)    nneq  type        position (cryst. coords)")')
       do j = 1, nn
          if (wat(j) /= 0) then
             write (uout,'(5X,"...",6X,I4,3X,F12.7,3X,I4,3X,A4,3A)') &
                nneig(j), dist(j), wat(j), cr%at(wat(j))%name, &
                (string(xenv(k,1,j),'f',12,7,ioj_right),k=1,3)
          end if
       end do
       write (uout,*)

       ! Detailed list of neighbors
       write (uout,'("+ Neighbors of (",A,",",A,",",A,")")') &
          string(x0(1),'f'), string(x0(2),'f'), string(x0(3),'f')
       write (uout,'(" Atom Id           position (cryst. coords)      Distance (bohr)")')
       do j = 1, nn
          if (wat(j) == 0) cycle
          do k = 1, nneig(j)
             write (uout,'(6(A,X))') &
                string(cr%at(wat(j))%name,5,ioj_center), string(wat(j),2),&
                (string(xenv(l,k,j),'f',12,7,ioj_right),l=1,3),&
                string(dist(j),'f',12,5,ioj_right)
          end do
       end do
       write (uout,*)
    end if
    deallocate(nneig,wat,dist)
    if (allocated(xenv)) deallocate(xenv)
    
  end subroutine struct_environ

  !> Calculate the packing ratio of the crystal.
  subroutine struct_packing(line)
    use struct_basic
    use global
    use tools_io
    use param

    character*(*), intent(in) :: line

    integer :: lp
    logical :: dovdw, found, ok
    character(len=:), allocatable :: word
    integer :: i, j, n(3), ii(3), ntot, iaux, idx
    integer :: lvec(3)
    real*8 :: prec, alpha, x(3), dist
    real*8 :: vout, dv

    ! default values    
    dovdw = .false.
    prec = 1d-1

    ! header
    write (uout,'("* PACKING")')

    ! parse input
    lp = 1
    do while (.true.)
       word = lgetword(line,lp)
       if (equal(word,"vdw")) then
          dovdw = .true.
       elseif (equal(word,"prec")) then
          ok = eval_next(prec,line,lp)
          if (.not.ok) call ferror('struct_packing','Wrong PREC syntax',faterr,line)
       elseif (len_trim(word) > 0) then
          call ferror('struct_packing','Unknown extra keyword',faterr,line)
       else
          exit
       end if
    end do
    
    if (.not.dovdw) then
       write (uout,'("+ Packing ratio (%): ",A)') string(cr%get_pack_ratio(),'f',10,4)
    else
       ! prepare the grid
       write (uout,'("+ Est. precision in the % packing ratio: ",A)') string(prec,'e',10,3)
       prec = prec * cr%omega / 100d0
       write (uout,'("+ Est. precision in the interstitial volume: ",A)') trim(string(prec,'f',100,4))
       alpha = (prec / cr%omega)**(1d0/3d0)
       n = ceiling(cr%aa / alpha)
       write (uout,'("+ Using a volume grid with # of nodes: ",3(A," "))') &
          (string(n(j)),j=1,3)
       
       ! run over all the points in the grid
       ntot = n(1)*n(2)*n(3)
       vout = 0d0
       dv = cr%omega / ntot

       !$omp parallel do reduction(+:vout) private(ii,iaux,x,found,idx,dist,lvec) schedule(dynamic)
       do i = 0, ntot-1
          ! unpack the index
          ii(1) = modulo(i,n(1))
          iaux = (i - ii(1)) / (n(1))
          ii(2) = modulo(iaux,n(2))
          iaux = (iaux - ii(2)) / (n(2))
          ii(3) = modulo(iaux,n(3))
          ! calculate the point in the cell
          x = real(ii,8) / real(n)

          found = .false.
          do j = 1, cr%nneq
             idx = j
             call cr%nearest_atom(x,idx,dist,lvec)
             found = (dist < atmvdw(cr%at(j)%z))
             if (found) exit
          end do
          if (.not.found) then
             vout = vout + dv
          end if
       end do
       !$omp end parallel do
       write (uout,'("+ Interstitial volume (outside vdw spheres): ",A)'), &
          trim(string(vout,'f',100,4))
       write (uout,'("+ Cell volume: ",A)') trim(string(cr%omega,'f',100,4))
       write (uout,'("+ Packing ratio (%): ",A)') string((cr%omega-vout)/cr%omega*100,'f',10,4)
    end if
    write (uout,*)

  end subroutine struct_packing

  !> Build a new crystal from the current crystal by cell transformation
  subroutine struct_newcell(line)
    use struct_basic
    use global
    use tools_math
    use tools_io
    character*(*), intent(in) :: line

    character(len=:), allocatable :: word
    logical :: ok
    integer :: lp
    real*8 :: x0(3,3)
    logical :: doinv

    ! read the vectors from the input
    lp = 1
    ok = eval_next(x0(1,1),line,lp)
    ok = ok .and. eval_next(x0(2,1),line,lp)
    ok = ok .and. eval_next(x0(3,1),line,lp)
    ok = ok .and. eval_next(x0(1,2),line,lp)
    ok = ok .and. eval_next(x0(2,2),line,lp)
    ok = ok .and. eval_next(x0(3,2),line,lp)
    ok = ok .and. eval_next(x0(1,3),line,lp)
    ok = ok .and. eval_next(x0(2,3),line,lp)
    ok = ok .and. eval_next(x0(3,3),line,lp)
    if (.not.ok) &
       call ferror("struct_newcell","Wrong syntax in NEWCELL",faterr,line)

    doinv = .false.
    do while (.true.)
       word = lgetword(line,lp)
       if (equal(word,"inv").or.equal(word,"inverse")) then
          doinv = .true.
       elseif (len_trim(word) > 0) then
          call ferror('struct_newcell','Unknown extra keyword',faterr,line)
       else
          exit
       end if
    end do
    if (doinv) x0 = matinv(x0)

    call cr%newcell(x0,.true.)

  end subroutine struct_newcell

  !> Try to determine the molecular cell from the crystal geometry
  subroutine struct_molcell(line)
    use struct_basic
    use global
    use tools_io

    character*(*), intent(in) :: line
    integer :: i, j, lp
    real*8 :: xmin(3), xmax(3), rborder, raux
    logical :: ok

    real*8, parameter :: rborder_def = 3d0

    if (.not.cr%ismolecule) &
       call ferror('struct_molcell','Use MOLCELL with MOLECULE, not CRYSTAL.',faterr)
    if (any(abs(cr%bb-90d0) > 1d-5)) &
       call ferror('struct_molcell','MOLCELL only allowed for orthogonal cells.',faterr)

    ! defaults
    rborder = rborder_def

    ! read optional border input
    lp = 1
    ok = eval_next(raux,line,lp)
    if (ok) rborder = raux

    ! find the encompassing cube
    xmin = 1d40
    xmax = -1d30
    do i = 1, cr%ncel
       do j = 1, 3
          xmin(j) = min(xmin(j),cr%at(i)%x(j))
          xmax(j) = max(xmax(j),cr%at(i)%x(j))
       end do
    end do

    ! apply the border
    do j = 1, 3
       xmin(j) = max(xmin(j) - rborder / cr%aa(j),0d0)
       xmax(j) = min(xmax(j) + rborder / cr%aa(j),1d0)
       cr%molborder(j) = min(xmin(j),1d0-xmax(j))
    end do

    ! some output
    write (uout,'("* MOLCELL: set up a molecular cell")')
    write (uout,'("+ Limit of the molecule within the cell (cryst coords):")')
    write (uout,'("  a axis: ",A," -> ",A)') trim(string(cr%molborder(1),'f',10,4)), trim(string(1d0-cr%molborder(1),'f',10,4))
    write (uout,'("  b axis: ",A," -> ",A)') trim(string(cr%molborder(2),'f',10,4)), trim(string(1d0-cr%molborder(2),'f',10,4))
    write (uout,'("  c axis: ",A," -> ",A)') trim(string(cr%molborder(3),'f',10,4)), trim(string(1d0-cr%molborder(3),'f',10,4))
    
  end subroutine struct_molcell

end module struct
