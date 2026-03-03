! Benchmark Fortran server
! Uses iso_c_binding to call a C "glue" layer (mongoose + libpq)
! The Fortran side handles the "business logic" (trivial here)
! while C handles HTTP/WS/DB.

module bench_logic
  use iso_c_binding
  implicit none
contains

  ! Process an item creation - returns a JSON string via C buffer
  subroutine process_create(name, name_len, val, val_len, &
                            out_buf, out_len) bind(C, name="fortran_process_create")
    character(kind=c_char), intent(in) :: name(*)
    integer(c_int), value, intent(in) :: name_len
    character(kind=c_char), intent(in) :: val(*)
    integer(c_int), value, intent(in) :: val_len
    character(kind=c_char), intent(out) :: out_buf(4096)
    integer(c_int), intent(out) :: out_len

    ! In this benchmark, the Fortran "logic" is trivial:
    ! Just copy input to output buffer as JSON-ready strings.
    ! The actual DB insert is done by the C glue layer.
    integer :: i
    out_len = 0
    do i = 1, min(name_len, 2048)
      out_buf(out_len + 1) = name(i)
      out_len = out_len + 1
    end do
  end subroutine process_create

  ! Validate an item id (returns 1 if valid, 0 otherwise)
  function validate_id(id) result(valid) bind(C, name="fortran_validate_id")
    integer(c_int), value, intent(in) :: id
    integer(c_int) :: valid
    if (id > 0) then
      valid = 1
    else
      valid = 0
    end if
  end function validate_id

end module bench_logic
