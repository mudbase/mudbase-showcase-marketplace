import { useState } from "react";
import { FlatList, Modal, Pressable, Text, View } from "react-native";
import { Check, ChevronDown } from "lucide-react-native";
import { cn } from "@/lib/cn";

export interface SelectOption<T extends string> {
  value: T;
  label: string;
}

interface SelectFieldProps<T extends string> {
  label?: string;
  value: T;
  options: ReadonlyArray<SelectOption<T>>;
  onChange: (value: T) => void;
  className?: string;
}

/**
 * There is no native RN `<select>` — this renders the current value as a pressable field that
 * opens a small centered `Modal` listing every option as a tappable row, the same pattern the
 * sibling `mudbase-showcase-kanban/mobile-expo` port's `MoveCardPicker` uses for its own "pick one
 * of a short list" interaction. Used for the listing category filter, the listing status field,
 * and (indirectly, via two plain buttons rather than this component) the register screen's
 * client/freelancer role choice.
 */
export function SelectField<T extends string>({
  label,
  value,
  options,
  onChange,
  className,
}: SelectFieldProps<T>): React.JSX.Element {
  const [open, setOpen] = useState(false);
  const current = options.find((o) => o.value === value);

  return (
    <View className={cn("gap-1.5", className)}>
      {label && <Text className="text-sm font-medium text-foreground">{label}</Text>}
      <Pressable
        accessibilityRole="button"
        accessibilityLabel={label ? `${label}: ${current?.label ?? "Select"}` : "Select"}
        onPress={() => setOpen(true)}
        className="flex-row items-center justify-between rounded-md border border-border bg-card px-3 py-2.5"
      >
        <Text className="text-base text-foreground">{current?.label ?? "Select…"}</Text>
        <ChevronDown size={18} color="#606876" />
      </Pressable>

      <Modal visible={open} transparent animationType="fade" onRequestClose={() => setOpen(false)}>
        <Pressable className="flex-1 justify-end bg-black/40" onPress={() => setOpen(false)}>
          <Pressable className="max-h-96 rounded-t-lg bg-card p-2" onPress={(e) => e.stopPropagation()}>
            <FlatList
              data={options}
              keyExtractor={(item) => item.value}
              renderItem={({ item }) => (
                <Pressable
                  accessibilityRole="button"
                  onPress={() => {
                    onChange(item.value);
                    setOpen(false);
                  }}
                  className="flex-row items-center justify-between rounded-md px-4 py-3 active:bg-secondary"
                >
                  <Text className="text-base text-foreground">{item.label}</Text>
                  {item.value === value && <Check size={18} color="#1d8663" />}
                </Pressable>
              )}
            />
          </Pressable>
        </Pressable>
      </Modal>
    </View>
  );
}
