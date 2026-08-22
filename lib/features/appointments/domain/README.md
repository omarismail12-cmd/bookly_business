# Appointments domain

Authoritative booking operations must use Supabase RPCs:

- `get_available_slots`
- `create_booking`
- `reschedule_appointment`
- `cancel_appointment`
- `change_appointment_status`

Do not insert/update `appointments` directly from presentation code.
