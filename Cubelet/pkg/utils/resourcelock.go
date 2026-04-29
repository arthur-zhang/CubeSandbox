// Copyright (c) 2024 Tencent Inc.
// SPDX-License-Identifier: Apache-2.0
//

package utils

import (
	"sync"
)

type ResMutex struct {
	mtx   *sync.Mutex
	count int
}

type ResourceLocks struct {
	mutex sync.Mutex
	locks map[string]*ResMutex
}

func NewResourceLocks() *ResourceLocks {
	return &ResourceLocks{
		mutex: sync.Mutex{},
		locks: make(map[string]*ResMutex),
	}
}

func (r *ResourceLocks) Lock(resource string) func() {
	r.mutex.Lock()

	l, ok := r.locks[resource]
	if ok {
		l.count++
	} else {
		r.locks[resource] = &ResMutex{
			mtx:   &sync.Mutex{},
			count: 1,
		}
		l, _ = r.locks[resource]
	}

	r.mutex.Unlock()

	l.mtx.Lock()

	return r.makeUnlock(resource, l)
}

// TryLock attempts to acquire the per-resource lock without blocking.
// On success it returns an unlock function and true. On failure (already
// held by another caller) it returns nil and false.
func (r *ResourceLocks) TryLock(resource string) (func(), bool) {
	r.mutex.Lock()

	l, ok := r.locks[resource]
	if ok {
		l.count++
	} else {
		r.locks[resource] = &ResMutex{
			mtx:   &sync.Mutex{},
			count: 1,
		}
		l = r.locks[resource]
	}

	r.mutex.Unlock()

	if !l.mtx.TryLock() {
		// Could not acquire; release the bookkeeping reference we just took.
		r.mutex.Lock()
		defer r.mutex.Unlock()
		if cur, ok := r.locks[resource]; ok {
			if cur.count == 1 {
				delete(r.locks, resource)
			} else {
				cur.count--
			}
		}
		return nil, false
	}

	return r.makeUnlock(resource, l), true
}

func (r *ResourceLocks) makeUnlock(resource string, l *ResMutex) func() {
	return func() {
		l.mtx.Unlock()

		r.mutex.Lock()
		defer r.mutex.Unlock()

		cur, ok := r.locks[resource]
		if ok {
			if cur.count == 1 {
				delete(r.locks, resource)
				return
			}
			cur.count--
		}
	}
}

func (r *ResourceLocks) Len() int {
	return len(r.locks)
}
