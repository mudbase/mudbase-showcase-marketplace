"use client"

import { ChevronLeft, ChevronRight } from "lucide-react"
import { Button } from "@/components/ui/button"
import type { PaginationMeta } from "@/lib/mudbase"

interface PaginationControlsProps {
  pagination: PaginationMeta | undefined
  onPageChange: (page: number) => void
}

export function PaginationControls({ pagination, onPageChange }: PaginationControlsProps): React.JSX.Element | null {
  if (!pagination || pagination.totalPages <= 1) return null

  return (
    <div className="flex items-center justify-between border-t border-border pt-4">
      <p className="text-sm text-muted-foreground">
        Page {pagination.page} of {pagination.totalPages} · {pagination.total} total
      </p>
      <div className="flex gap-2">
        <Button
          variant="outline"
          size="sm"
          disabled={pagination.page <= 1}
          onClick={() => onPageChange(pagination.page - 1)}
        >
          <ChevronLeft className="mr-1 h-4 w-4" />
          Previous
        </Button>
        <Button variant="outline" size="sm" disabled={!pagination.hasMore} onClick={() => onPageChange(pagination.page + 1)}>
          Next
          <ChevronRight className="ml-1 h-4 w-4" />
        </Button>
      </div>
    </div>
  )
}
