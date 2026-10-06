-- Phase 1 / Migration 1 of 10: extensions
-- Run this FIRST in the Supabase SQL editor.

create extension if not exists pgcrypto with schema extensions;
