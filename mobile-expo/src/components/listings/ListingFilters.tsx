import { View } from "react-native";
import { TextField } from "@/components/ui/TextField";
import { SelectField } from "@/components/ui/SelectField";

export interface ListingFilterValues {
  search: string;
  category: string;
  minBudget: string;
  maxBudget: string;
}

interface ListingFiltersProps {
  values: ListingFilterValues;
  categories: string[];
  onChange: (values: ListingFilterValues) => void;
}

const ALL_CATEGORIES = "__all__";

export function ListingFilters({ values, categories, onChange }: ListingFiltersProps): React.JSX.Element {
  return (
    <View className="gap-3 rounded-lg border border-border bg-card p-4">
      <TextField
        label="Search"
        placeholder="Search title or description…"
        value={values.search}
        onChangeText={(text) => onChange({ ...values, search: text })}
        autoCapitalize="none"
        autoCorrect={false}
        returnKeyType="search"
      />
      <SelectField
        label="Category"
        value={values.category || ALL_CATEGORIES}
        onChange={(v) => onChange({ ...values, category: v === ALL_CATEGORIES ? "" : v })}
        options={[
          { value: ALL_CATEGORIES, label: "All categories" },
          ...categories.map((category) => ({ value: category, label: category })),
        ]}
      />
      <View className="flex-row gap-2">
        <TextField
          label="Min budget"
          keyboardType="numeric"
          placeholder="Min"
          value={values.minBudget}
          onChangeText={(text) => onChange({ ...values, minBudget: text.replace(/[^0-9]/g, "") })}
          containerClassName="flex-1"
        />
        <TextField
          label="Max budget"
          keyboardType="numeric"
          placeholder="Max"
          value={values.maxBudget}
          onChangeText={(text) => onChange({ ...values, maxBudget: text.replace(/[^0-9]/g, "") })}
          containerClassName="flex-1"
        />
      </View>
    </View>
  );
}
