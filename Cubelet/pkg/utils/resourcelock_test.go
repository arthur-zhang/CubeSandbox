// Copyright (c) 2024 Tencent Inc.
// SPDX-License-Identifier: Apache-2.0
//

package utils

import (
	"sync"
	"testing"
)

func TestResourceLock(t *testing.T) {
	locks := NewResourceLocks()

	const (
		resource = "xxx"
		n        = 10000
	)

	var result int64

	wg := sync.WaitGroup{}
	wg.Add(n)
	for i := 0; i < n; i++ {
		go func() {
			defer wg.Done()

			unlock := locks.Lock(resource)
			defer unlock()

			result++
		}()
	}
	wg.Wait()

	if result != n || locks.Len() != 0 {
		t.Fatal("lock failed")
	}
}

func TestResourceLocks(t *testing.T) {
	locks := NewResourceLocks()
	const n = 10000

	var (
		results   = [3]int64{}
		resources = [3]string{"aaa", "bbb", "ccc"}
	)

	wg := sync.WaitGroup{}
	wg.Add(n)
	for i := 0; i < n; i++ {
		go func(x int) {
			defer wg.Done()

			i := x % len(resources)
			unlock := locks.Lock(resources[i])
			defer unlock()

			results[i]++
		}(i)
	}
	wg.Wait()

	if results[0]+results[1]+results[2] != n || locks.Len() != 0 {
		t.Fatal("lock failed")
	}
}

func TestResourceLocks_TryLock(t *testing.T) {
	locks := NewResourceLocks()

	// Initially free: TryLock should succeed.
	unlock1, ok := locks.TryLock("res1")
	if !ok || unlock1 == nil {
		t.Fatal("first TryLock should succeed")
	}

	// Already held: TryLock for the same resource should fail without
	// blocking and must not leak a bookkeeping entry.
	if u, ok := locks.TryLock("res1"); ok || u != nil {
		t.Fatal("contended TryLock should fail")
	}

	// Different resource is independent.
	unlock2, ok := locks.TryLock("res2")
	if !ok || unlock2 == nil {
		t.Fatal("TryLock on a different resource should succeed")
	}

	unlock1()
	unlock2()

	if locks.Len() != 0 {
		t.Fatalf("expected all entries cleaned up, got %d", locks.Len())
	}

	// After release, TryLock should succeed again.
	unlock3, ok := locks.TryLock("res1")
	if !ok {
		t.Fatal("TryLock after unlock should succeed")
	}
	unlock3()

	if locks.Len() != 0 {
		t.Fatalf("expected 0 entries, got %d", locks.Len())
	}
}
