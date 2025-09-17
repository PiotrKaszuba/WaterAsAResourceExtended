def check_tick_update_collisions(updates_every: list[int], shifts: list[int], num_ticks: int = 1000 * 60):
    num_updates_per_tick = []
    update_types = [0, 0, 0]
    num_updates_per_tick_with_restriction = []
    update_types_with_restriction = [0, 0, 0]
    for i in range(num_ticks):
        sum_updates = 0
        sum_updates_with_restriction = 0
        for j, (update_every, shift) in enumerate(zip(updates_every, shifts)):
            if i % update_every == shift:
                sum_updates += 1
                update_types[j] += 1
                if sum_updates_with_restriction == 0:
                    sum_updates_with_restriction += 1
                    update_types_with_restriction[j] += 1
        num_updates_per_tick.append(sum_updates)
        num_updates_per_tick_with_restriction.append(sum_updates_with_restriction)

    average_update_types = [ut / num_ticks * 60 for ut in update_types]
    average_update_types_with_restriction = [ut / num_ticks * 60 for ut in update_types_with_restriction]

    print(f"Updates every: {updates_every}")
    print(f"Shifts: {shifts}")
    print("-" * 20)
    print(f"Max updates per tick: {max(num_updates_per_tick)}")
    print(f"Average updates per tick: {sum(num_updates_per_tick) / num_ticks}")
    print(f"Average update types per second: {average_update_types}")
    print("-" * 20)
    print(f"Max updates per tick with restriction: {max(num_updates_per_tick_with_restriction)}")
    print(f"Average updates per tick with restriction: {sum(num_updates_per_tick_with_restriction) / num_ticks}")
    print(f"Average update types per second with restriction: {average_update_types_with_restriction}")
    
    print("=" * 20)



if __name__ == "__main__":
    check_tick_update_collisions([30, 10, 5], [0, 1, 2])
    check_tick_update_collisions([30, 6, 3], [0, 1, 2])
    check_tick_update_collisions([30, 2, 2], [0, 0, 1])
    check_tick_update_collisions([30, 3, 1], [0, 1, 0])