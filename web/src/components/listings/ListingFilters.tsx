"use client"

import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select"

export interface ListingFilterValues {
  search: string
  category: string
  minBudget: string
  maxBudget: string
}

interface ListingFiltersProps {
  values: ListingFilterValues
  categories: string[]
  onChange: (values: ListingFilterValues) => void
}

const ALL_CATEGORIES = "__all__"

export function ListingFilters({ values, categories, onChange }: ListingFiltersProps): React.JSX.Element {
  return (
    <div className="grid gap-4 rounded-lg border border-border bg-card p-4 sm:grid-cols-4">
      <div className="space-y-1.5 sm:col-span-2">
        <Label htmlFor="search">Search</Label>
        <Input
          id="search"
          placeholder="Search title or description…"
          value={values.search}
          onChange={(e) => onChange({ ...values, search: e.target.value })}
        />
      </div>
      <div className="space-y-1.5">
        <Label htmlFor="category">Category</Label>
        <Select
          value={values.category || ALL_CATEGORIES}
          onValueChange={(v) => onChange({ ...values, category: v === ALL_CATEGORIES ? "" : v })}
        >
          <SelectTrigger id="category">
            <SelectValue placeholder="All categories" />
          </SelectTrigger>
          <SelectContent>
            <SelectItem value={ALL_CATEGORIES}>All categories</SelectItem>
            {categories.map((category) => (
              <SelectItem key={category} value={category}>
                {category}
              </SelectItem>
            ))}
          </SelectContent>
        </Select>
      </div>
      <div className="space-y-1.5">
        <Label>Budget range</Label>
        <div className="flex gap-2">
          <Input
            inputMode="numeric"
            placeholder="Min"
            value={values.minBudget}
            onChange={(e) => onChange({ ...values, minBudget: e.target.value.replace(/[^0-9]/g, "") })}
          />
          <Input
            inputMode="numeric"
            placeholder="Max"
            value={values.maxBudget}
            onChange={(e) => onChange({ ...values, maxBudget: e.target.value.replace(/[^0-9]/g, "") })}
          />
        </div>
      </div>
    </div>
  )
}
